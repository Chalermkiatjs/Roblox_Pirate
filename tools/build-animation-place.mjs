import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import assert from 'node:assert/strict';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const luau = process.argv[2];
if (!luau) throw new Error('Usage: node tools/build-animation-place.mjs <luau executable>');
const moves = JSON.parse(execFileSync(luau, ['tools/export-moveset.luau'], { cwd: root, encoding: 'utf8' }));
const rigs = JSON.parse(fs.readFileSync(path.join(root, 'assets/animations/rig-bindings.json'), 'utf8'));
let counter = 0;
const id = () => `RBX${++counter}`;
const escape = value => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const p = (type, name, value) => `<${type} name="${name}">${escape(value)}</${type}>`;
const vector = (name, xyz) => `<Vector3 name="${name}"><X>${xyz[0]}</X><Y>${xyz[1]}</Y><Z>${xyz[2]}</Z></Vector3>`;
const identity = [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1];
const cf = (name, values) => `<CoordinateFrame name="${name}">${['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'].map((key, i) => `<${key}>${values[i]}</${key}>`).join('')}</CoordinateFrame>`;
const color = (name, rgb) => `<Color3 name="${name}"><R>${rgb[0]}</R><G>${rgb[1]}</G><B>${rgb[2]}</B></Color3>`;
const item = (cls, name, properties = '', children = '', ref = id()) => `<Item class="${cls}" referent="${ref}"><Properties>${p('string', 'Name', name)}${properties}</Properties>${children}</Item>`;
const multiply = (a, b) => Array.from({length: 9}, (_, n) => {
    const row = Math.floor(n / 3), col = n % 3;
    return a[row * 3] * b[col] + a[row * 3 + 1] * b[3 + col] + a[row * 3 + 2] * b[6 + col];
});
function rotation(angles, bind) {
    const [x, y, z] = angles.map(a => a * Math.PI / 180);
    const [sx, sy, sz, cx, cy, cz] = [Math.sin(x), Math.sin(y), Math.sin(z), Math.cos(x), Math.cos(y), Math.cos(z)];
    const r = [cy*cz, -cy*sz, sy, cx*sz+sx*sy*cz, cx*cz-sx*sy*sz, -sx*cy, sx*sz-cx*sy*cz, sx*cz+cx*sy*sz, cx*cy];
    const b = bind.slice(3), inverse = [b[0],b[3],b[6],b[1],b[4],b[7],b[2],b[5],b[8]];
    return [0, 0, 0, ...multiply(multiply(inverse, r), b)];
}
const rigXml = [], savesXml = [];
for (const [kind, rig] of Object.entries(rigs)) {
    const rigRef = id(), saveRef = id();
    const refs = Object.fromEntries(rig.parts.map(part => [part.name, id()]));
    const jointFor = Object.fromEntries(rig.joints.map(j => [j.part1, j]));
    const children = {};
    for (const joint of rig.joints) (children[joint.part0] ??= []).push(joint);
    const torso = kind === 'R6' ? 'Torso' : 'UpperTorso';
    const right = kind === 'R6' ? 'Right Arm' : 'RightUpperArm';
    const left = kind === 'R6' ? 'Left Arm' : 'LeftUpperArm';
    function poseTree(partName, angles) {
        const role = partName === torso ? 'torso' : partName === right ? 'right' : partName === left ? 'left' : null;
        const descendants = (children[partName] ?? []).map(j => poseTree(j.part1, angles)).join('');
        const transform = role ? rotation(angles[role], jointFor[partName].c0) : identity;
        return item('Pose', partName, cf('CFrame', transform) + p('float', 'Weight', role ? 1 : 0)
            + p('token', 'EasingStyle', 0) + p('token', 'EasingDirection', 2), descendants);
    }
    const clips = moves.map(move => {
        assert(move.frames.length >= 2);
        assert.equal(move.frames[0].time, 0);
        assert(Math.abs(move.frames.at(-1).time - move.duration) < 1e-6);
        if (move.windup) assert(move.frames.some(frame => Math.abs(frame.time - move.windup) < 1e-6));
        const frames = move.frames.map(frame => {
            let markers = '';
            if (move.windup && Math.abs(frame.time - move.windup) < 1e-6) markers += item('KeyframeMarker', 'Contact', p('string', 'Value', move.name));
            if (Math.abs(frame.time - move.duration) < 1e-6) markers += item('KeyframeMarker', 'RecoveryEnd', p('string', 'Value', move.name));
            return item('Keyframe', 'Keyframe', p('float', 'Time', frame.time), poseTree('HumanoidRootPart', frame.angles) + markers);
        }).join('');
        return item('KeyframeSequence', `Cutlass_${move.name}`, p('bool', 'Loop', move.loop)
            + p('token', 'Priority', move.name === 'Idle' ? 2 : 3), frames);
    }).join('');
    savesXml.push(item('ObjectValue', `Cutlass_${kind}`, p('Ref', 'Value', rigRef), clips, saveRef));
    const origin = [kind === 'R6' ? -5 : 5, 5, 0];
    const parts = rig.parts.map(part => {
        const frame = [...part.cframe];
        for (let i = 0; i < 3; i++) frame[i] += origin[i];
        const motors = (children[part.name] ?? []).map(j => item('Motor6D', j.name,
            p('Ref', 'Part0', refs[j.part0]) + p('Ref', 'Part1', refs[j.part1]) + cf('C0', j.c0) + cf('C1', j.c1))).join('');
        return item('Part', part.name, vector('size', part.size) + cf('CFrame', frame)
            + color('Color', part.name === 'Head' ? [0.83,0.68,0.53] : kind === 'R6' ? [0.27,0.52,0.43] : [0.65,0.27,0.26])
            + p('float', 'Transparency', part.transparency) + p('bool', 'Anchored', part.name === 'HumanoidRootPart')
            + p('bool', 'CanCollide', false) + p('token', 'TopSurface', 0) + p('token', 'BottomSurface', 0), motors, refs[part.name]);
    }).join('');
    const humanoid = item('Humanoid', 'Humanoid', p('token', 'RigType', kind === 'R6' ? 0 : 1)
        + p('float', 'HipHeight', rig.hipHeight) + p('bool', 'RequiresNeck', true), item('Animator', 'Animator'));
    rigXml.push(item('Model', `Cutlass_${kind}`, p('Ref', 'PrimaryPart', refs.HumanoidRootPart),
        parts + humanoid + item('ObjectValue', 'AnimSaves', p('Ref', 'Value', saveRef)), rigRef));
}
const base = item('Part', 'Stage', vector('size', [32, 1, 24]) + cf('CFrame', identity)
    + p('bool', 'Anchored', true) + color('Color', [0.14,0.17,0.17]));
const camera = item('Camera', 'Camera', cf('CFrame', [0,8,18,1,0,0,0,0.9864,0.1644,0,-0.1644,0.9864]));
const xml = `<?xml version="1.0" encoding="utf-8"?><roblox version="4"><External>null</External><External>nil</External>${item('Workspace','Workspace','',base+camera+rigXml.join(''))}${item('ServerStorage','ServerStorage','',item('Model','RBX_ANIMSAVES','',savesXml.join('')))}${item('Lighting','Lighting',p('float','ClockTime',14)+p('float','Brightness',2))}</roblox>`;
const output = path.join(root, 'assets/animations', process.argv[3] || 'PirateOcean_Animations.rbxlx');
fs.writeFileSync(output, xml);
console.log(`Built ${output}: 2 rigs, ${moves.length * 2} clips, contact/recovery markers.`);
