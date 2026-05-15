import * as THREE from "https://esm.sh/three@0.160.0";
import { CELL_SIZE, CELLS_X, CELLS_Z, collides, moveAndCollide } from "./maze.js";

// Slender-style figure: very tall, dark suit, white face. The "fear" of it
// is mostly carried by the ambience + jumpscare; the model is intentionally
// simple so it remains creepy in low light without looking goofy.
export function createMonster(scene) {
  const group = new THREE.Group();

  const suitMat = new THREE.MeshStandardMaterial({ color: 0x070707, roughness: 1.0 });
  const skinMat = new THREE.MeshStandardMaterial({
    color: 0xeeeeee,
    roughness: 0.4,
    emissive: 0x111111,
  });
  const eyeMat = new THREE.MeshBasicMaterial({ color: 0x000000 });

  const bodyH = 2.5;
  const body = new THREE.Mesh(new THREE.CylinderGeometry(0.35, 0.45, bodyH, 8), suitMat);
  body.position.y = bodyH / 2;
  group.add(body);

  // Arms (long & dangling)
  const armGeo = new THREE.CylinderGeometry(0.08, 0.06, 2.0, 6);
  const armL = new THREE.Mesh(armGeo, suitMat);
  armL.position.set(-0.45, 1.8, 0);
  armL.rotation.z = 0.15;
  group.add(armL);
  const armR = armL.clone();
  armR.position.x = 0.45;
  armR.rotation.z = -0.15;
  group.add(armR);

  // Head
  const head = new THREE.Mesh(new THREE.SphereGeometry(0.32, 16, 12), skinMat);
  head.position.y = bodyH + 0.32;
  group.add(head);

  // Eye sockets (dark dots)
  const eyeGeo = new THREE.SphereGeometry(0.045, 8, 6);
  const eyeL = new THREE.Mesh(eyeGeo, eyeMat);
  eyeL.position.set(-0.11, bodyH + 0.36, 0.28);
  group.add(eyeL);
  const eyeR = new THREE.Mesh(eyeGeo, eyeMat);
  eyeR.position.set(0.11, bodyH + 0.36, 0.28);
  group.add(eyeR);

  // Soft glowing "presence" point light, very dim, dark red — makes the
  // figure barely visible from afar like a smouldering shape
  const glow = new THREE.PointLight(0x661010, 0.6, 4, 2);
  glow.position.set(0, bodyH + 0.4, 0);
  group.add(glow);

  // Total height ~3.1 — clearly taller than player
  group.scale.set(1, 1, 1);
  group.visible = false; // hidden until first warp
  scene.add(group);

  return {
    mesh: group,
    head,
    speed: 1.4,           // current speed in units/sec, will increase with pages
    awareness: 0,         // 0..1 — how close the monster is mentally
    catchRadius: 1.1,
    teleportCooldown: 0,
    lastSeenTime: 0,
    visibleToPlayerNow: false,
  };
}

export function spawnMonsterAtCell(monster, cellX, cellZ) {
  monster.mesh.position.set(
    cellX * CELL_SIZE + CELL_SIZE / 2,
    0,
    cellZ * CELL_SIZE + CELL_SIZE / 2
  );
  monster.mesh.visible = true;
}

// Picks a cell at distance D from player, with some randomness
function pickFarCell(playerX, playerZ, minDist, maxDist) {
  for (let i = 0; i < 60; i++) {
    const cx = Math.floor(Math.random() * CELLS_X);
    const cz = Math.floor(Math.random() * CELLS_Z);
    const wx = cx * CELL_SIZE + CELL_SIZE / 2;
    const wz = cz * CELL_SIZE + CELL_SIZE / 2;
    const d = Math.hypot(wx - playerX, wz - playerZ);
    if (d >= minDist && d <= maxDist) return { cx, cz, wx, wz, d };
  }
  // Fallback
  return { cx: CELLS_X - 1, cz: CELLS_Z - 1,
           wx: (CELLS_X - 0.5) * CELL_SIZE, wz: (CELLS_Z - 0.5) * CELL_SIZE,
           d: 100 };
}

// Updates monster each frame. Returns "caught" if player was caught.
export function updateMonster(monster, player, walls, dt, pagesCollected, isMonsterVisible) {
  const m = monster.mesh;
  if (!m.visible) return false;

  // The monster only physically advances when the player is NOT looking at it
  // (Weeping-Angel rule). It will teleport when far + unseen.
  monster.teleportCooldown -= dt;
  monster.visibleToPlayerNow = isMonsterVisible;

  if (!isMonsterVisible) {
    monster.lastSeenTime += dt;

    // Move toward player
    const dx = player.x - m.position.x;
    const dz = player.z - m.position.z;
    const dist = Math.hypot(dx, dz);
    if (dist > 0.001) {
      const stepLen = monster.speed * dt;
      const sx = (dx / dist) * stepLen;
      const sz = (dz / dist) * stepLen;
      const next = moveAndCollide(walls, m.position.x, m.position.z, sx, sz, 0.5);
      m.position.x = next.x;
      m.position.z = next.z;
    }
    // Make him face the player
    m.lookAt(player.x, m.position.y + 1, player.z);

    // Occasional teleport closer if it's been "lost" too long
    if (monster.teleportCooldown <= 0 && monster.lastSeenTime > 3.0 && dist > 14) {
      const target = pickFarCell(player.x, player.z, 6, 10);
      m.position.set(target.wx, 0, target.wz);
      monster.teleportCooldown = 6 + Math.random() * 4;
      monster.lastSeenTime = 0;
    }
  } else {
    // While visible, frozen — but turn head slightly to track player (subtle)
    monster.lastSeenTime = 0;
    m.lookAt(player.x, m.position.y + 1, player.z);
  }

  // Speed scales with pages collected (more aggressive as game progresses)
  monster.speed = 1.4 + pagesCollected * 0.5;

  // Caught?
  const dxp = player.x - m.position.x;
  const dzp = player.z - m.position.z;
  if (Math.hypot(dxp, dzp) < monster.catchRadius) return true;
  return false;
}

// Returns true if there's a clear line of sight from player camera to monster
// AND monster is roughly inside camera frustum.
export function isMonsterInView(camera, monster, walls) {
  const m = monster.mesh;
  if (!m.visible) return false;
  // Quick frustum check
  camera.updateMatrixWorld();
  const frustum = new THREE.Frustum().setFromProjectionMatrix(
    new THREE.Matrix4().multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse)
  );
  const head = new THREE.Vector3(m.position.x, m.position.y + 2.5, m.position.z);
  if (!frustum.containsPoint(head)) return false;

  // Line of sight: walk a ray from camera to monster head, check wall collisions
  const from = new THREE.Vector3();
  camera.getWorldPosition(from);
  const dir = head.clone().sub(from);
  const dist = dir.length();
  dir.normalize();
  const STEPS = 24;
  for (let i = 1; i < STEPS; i++) {
    const t = (i / STEPS) * dist;
    const px = from.x + dir.x * t;
    const pz = from.z + dir.z * t;
    if (collides(walls, px, pz, 0.05)) return false;
  }
  return true;
}
