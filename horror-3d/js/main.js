import * as THREE from "https://esm.sh/three@0.160.0";
import { PointerLockControls } from "https://esm.sh/three@0.160.0/examples/jsm/controls/PointerLockControls.js";

import {
  generateMaze, buildMazeMesh, moveAndCollide,
  CELL_SIZE, CELLS_X, CELLS_Z,
} from "./maze.js";
import { createMonster, spawnMonsterAtCell, updateMonster, isMonsterInView } from "./monster.js";
import { AudioEngine } from "./audio.js";
import {
  showMessage, setPages, setStamina, flashOverlay, staticBurst, shakeScreen,
  drawJumpscare, hideJumpscare, showGameOver, hideGameOver,
  showHUD, hideHUD, hideIntro, showPause, hidePause, showIntro,
} from "./ui.js";

const PAGES_TOTAL = 5;

const state = {
  scene: null,
  camera: null,
  renderer: null,
  controls: null,
  audio: new AudioEngine(),
  walls: [],
  pages: [],   // {mesh, light, collected}
  collected: 0,
  monster: null,
  flashlight: null,
  flashlightOn: true,
  flashlightBattery: 1.0,
  stamina: 1.0,
  running: false,
  paused: false,
  gameOver: false,
  win: false,
  velocityY: 0,
  lastTime: performance.now(),
  keys: new Set(),
  jumpscareUntil: 0,
  nextRandomJumpscare: 35 + Math.random() * 35,   // first ~35-70s
  bornAt: 0,
  footstepTimer: 0,
  cameraShake: 0,
  flashlightFlickerTimer: 0,
};

init();

function init() {
  setupThree();
  buildWorld();
  bindInput();
  bindUI();
  loop();
}

function setupThree() {
  const canvas = document.getElementById("game");
  state.renderer = new THREE.WebGLRenderer({
    canvas, antialias: false, powerPreference: "high-performance",
  });
  state.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.75));
  state.renderer.setSize(window.innerWidth, window.innerHeight);
  state.renderer.shadowMap.enabled = true;
  state.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  state.renderer.outputColorSpace = THREE.SRGBColorSpace;
  state.renderer.toneMapping = THREE.ACESFilmicToneMapping;
  state.renderer.toneMappingExposure = 0.9;

  state.scene = new THREE.Scene();
  state.scene.background = new THREE.Color(0x000000);
  state.scene.fog = new THREE.FogExp2(0x000000, 0.18);

  state.camera = new THREE.PerspectiveCamera(
    74, window.innerWidth / window.innerHeight, 0.05, 60
  );
  state.camera.position.set(CELL_SIZE / 2, 1.65, CELL_SIZE / 2);

  // Pointer lock controls
  state.controls = new PointerLockControls(state.camera, document.body);
  state.controls.addEventListener("unlock", () => {
    if (state.running && !state.gameOver) {
      state.paused = true;
      showPause();
    }
  });
  state.controls.addEventListener("lock", () => {
    state.paused = false;
    hidePause();
  });

  window.addEventListener("resize", () => {
    state.camera.aspect = window.innerWidth / window.innerHeight;
    state.camera.updateProjectionMatrix();
    state.renderer.setSize(window.innerWidth, window.innerHeight);
  });

  // Lights: extremely dim ambient + flashlight attached to camera
  const ambient = new THREE.AmbientLight(0x0a0809, 0.18);
  state.scene.add(ambient);

  // Subtle hemi for ground/ceiling shading
  const hemi = new THREE.HemisphereLight(0x110a0a, 0x000000, 0.08);
  state.scene.add(hemi);

  const flashlight = new THREE.SpotLight(0xfff2c0, 14, 22, Math.PI / 7, 0.45, 1.3);
  flashlight.position.set(0, 0, 0);
  flashlight.castShadow = true;
  flashlight.shadow.mapSize.width = 1024;
  flashlight.shadow.mapSize.height = 1024;
  flashlight.shadow.camera.near = 0.1;
  flashlight.shadow.camera.far = 22;
  flashlight.shadow.bias = -0.0015;
  state.camera.add(flashlight);
  // Need a target that we'll move with camera direction
  flashlight.target.position.set(0, 0, -1);
  state.camera.add(flashlight.target);
  state.flashlight = flashlight;

  state.scene.add(state.camera);
}

function buildWorld() {
  const cells = generateMaze(Math.random());
  const built = buildMazeMesh(cells, state.scene);
  state.walls = built.walls;
  state.bounds = built.bounds;

  // Pages
  const pageMat = new THREE.MeshBasicMaterial({ color: 0xffffff });
  const pageGeo = new THREE.PlaneGeometry(0.5, 0.7);
  // Draw a "page" texture
  const pageTex = makePageTexture();
  pageMat.map = pageTex;
  built.pageSpots.forEach((spot) => {
    const m = new THREE.Mesh(pageGeo, pageMat);
    // Stick page on a random wall direction from the cell center
    m.position.set(spot.x, 1.3, spot.z);
    m.rotation.y = Math.random() * Math.PI * 2;
    // Subtle ghost light to make it findable but not too easy
    const lit = new THREE.PointLight(0xfff0c0, 0.4, 3.5, 1.6);
    lit.position.set(spot.x, 1.6, spot.z);
    state.scene.add(lit);
    state.scene.add(m);
    state.pages.push({ mesh: m, light: lit, x: spot.x, z: spot.z, collected: false });
  });

  // Monster — start far away
  state.monster = createMonster(state.scene);
  spawnMonsterAtCell(state.monster, CELLS_X - 1, CELLS_Z - 1);
}

function makePageTexture() {
  const size = 256;
  const cv = document.createElement("canvas");
  cv.width = size; cv.height = Math.floor(size * 1.4);
  const ctx = cv.getContext("2d");
  ctx.fillStyle = "#e8dfc8";
  ctx.fillRect(0, 0, cv.width, cv.height);
  // Stains
  for (let i = 0; i < 10; i++) {
    ctx.fillStyle = `rgba(120,80,30,${0.05 + Math.random() * 0.15})`;
    ctx.beginPath();
    ctx.arc(Math.random() * cv.width, Math.random() * cv.height, 10 + Math.random() * 40, 0, Math.PI * 2);
    ctx.fill();
  }
  // Scrawled drawings
  ctx.strokeStyle = "#1a0a08"; ctx.lineWidth = 2;
  ctx.beginPath();
  const cx = cv.width / 2, cy = cv.height / 2;
  // tall figure
  ctx.moveTo(cx, cy - 60); ctx.lineTo(cx, cy + 60);
  ctx.moveTo(cx - 25, cy - 30); ctx.lineTo(cx + 25, cy - 30);
  ctx.moveTo(cx, cy + 60); ctx.lineTo(cx - 20, cy + 100);
  ctx.moveTo(cx, cy + 60); ctx.lineTo(cx + 20, cy + 100);
  // head
  ctx.arc(cx, cy - 70, 14, 0, Math.PI * 2);
  ctx.stroke();
  // text
  ctx.fillStyle = "#2a0a0a";
  ctx.font = "bold 18px serif";
  const lines = [
    "НЕ СМОТРИ НА НЕГО",
    "ОН ИЗ СТЕН",
    "ОН ВСЕГДА БЛИЗКО",
    "СТРАНИЦЫ НЕ ВЫПУСКАЮТ",
    "Я НЕ МОГУ УЙТИ",
    "ОН НЕ ЛЮБИТ СВЕТ",
    "..помогите..",
  ];
  const l1 = lines[Math.floor(Math.random() * lines.length)];
  const l2 = lines[Math.floor(Math.random() * lines.length)];
  ctx.fillText(l1, 20, 30);
  ctx.fillText(l2, 20, cv.height - 24);
  const tex = new THREE.CanvasTexture(cv);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

function bindInput() {
  document.addEventListener("keydown", (e) => {
    const k = e.code;
    state.keys.add(k);
    if (k === "KeyF" && state.running && !state.paused) toggleFlashlight();
    if (k === "Escape" && state.running && !state.paused) state.controls.unlock();
  });
  document.addEventListener("keyup", (e) => state.keys.delete(e.code));
}

function bindUI() {
  document.getElementById("startBtn").addEventListener("click", () => {
    startGame();
  });
  document.getElementById("resumeBtn").addEventListener("click", () => {
    state.controls.lock();
  });
  document.getElementById("restartBtn").addEventListener("click", () => {
    location.reload();
  });
}

function startGame() {
  hideIntro();
  showHUD();
  setPages(0, PAGES_TOTAL);
  setStamina(1);
  state.audio.start();
  state.running = true;
  state.bornAt = performance.now();
  // Small delayed door creak as you enter
  setTimeout(() => state.audio.doorCreak(), 700);
  setTimeout(() => state.audio.doorCreak(), 1800);
  // First whisper a bit later
  // pointer lock
  state.controls.lock();
}

function toggleFlashlight() {
  state.flashlightOn = !state.flashlightOn;
  state.flashlight.intensity = state.flashlightOn ? 14 : 0;
  state.audio.flashlightClick();
}

function loop() {
  requestAnimationFrame(loop);
  const now = performance.now();
  let dt = (now - state.lastTime) / 1000;
  state.lastTime = now;
  if (dt > 0.1) dt = 0.1;

  if (state.running && !state.paused && !state.gameOver) tick(dt);
  if (state.jumpscareUntil && now > state.jumpscareUntil) {
    if (!state.gameOver) hideJumpscare();
    state.jumpscareUntil = 0;
  }

  // Camera shake (simple jitter)
  if (state.cameraShake > 0) {
    state.cameraShake -= dt * 2;
    const s = Math.max(0, state.cameraShake) * 0.04;
    state.camera.position.x += (Math.random() - 0.5) * s;
    state.camera.position.z += (Math.random() - 0.5) * s;
  }

  state.renderer.render(state.scene, state.camera);
}

function tick(dt) {
  movePlayer(dt);
  updatePages();
  updateMonsterAndScares(dt);
  updateFlashlight(dt);
  updateAudioState(dt);

  // Random small jumpscare
  const elapsed = (performance.now() - state.bornAt) / 1000;
  if (elapsed > state.nextRandomJumpscare) {
    state.nextRandomJumpscare = elapsed + 30 + Math.random() * 40;
    triggerMiniScare();
  }
}

function movePlayer(dt) {
  const fwd = state.keys.has("KeyW") || state.keys.has("ArrowUp");
  const back = state.keys.has("KeyS") || state.keys.has("ArrowDown");
  const left = state.keys.has("KeyA") || state.keys.has("ArrowLeft");
  const right = state.keys.has("KeyD") || state.keys.has("ArrowRight");
  const sprint = (state.keys.has("ShiftLeft") || state.keys.has("ShiftRight")) && state.stamina > 0.05;

  const baseSpeed = 2.6;
  const sprintMul = sprint ? 1.9 : 1.0;
  const speed = baseSpeed * sprintMul;

  // Get camera forward/right on XZ plane
  const fwdVec = new THREE.Vector3();
  state.camera.getWorldDirection(fwdVec);
  fwdVec.y = 0; fwdVec.normalize();
  const rightVec = new THREE.Vector3().crossVectors(fwdVec, new THREE.Vector3(0, 1, 0)).normalize();

  let dx = 0, dz = 0;
  if (fwd)   { dx += fwdVec.x; dz += fwdVec.z; }
  if (back)  { dx -= fwdVec.x; dz -= fwdVec.z; }
  if (right) { dx += rightVec.x; dz += rightVec.z; }
  if (left)  { dx -= rightVec.x; dz -= rightVec.z; }

  const len = Math.hypot(dx, dz);
  const moving = len > 0.001;
  if (moving) { dx /= len; dz /= len; }

  const px = state.camera.position.x;
  const pz = state.camera.position.z;
  const next = moveAndCollide(state.walls, px, pz, dx * speed * dt, dz * speed * dt, 0.35);
  state.camera.position.x = next.x;
  state.camera.position.z = next.z;

  // Bobbing
  if (moving) {
    const t = performance.now() / 1000;
    state.camera.position.y = 1.65 + Math.sin(t * (sprint ? 12 : 7)) * (sprint ? 0.06 : 0.035);
    state.footstepTimer -= dt * (sprint ? 1.8 : 1.0);
    if (state.footstepTimer <= 0) {
      state.footstepTimer = sprint ? 0.32 : 0.5;
      state.audio.footstep();
    }
  } else {
    state.camera.position.y += (1.65 - state.camera.position.y) * 0.2;
  }

  // Stamina
  if (sprint && moving) state.stamina = Math.max(0, state.stamina - dt * 0.28);
  else state.stamina = Math.min(1, state.stamina + dt * 0.12);
  setStamina(state.stamina);
}

function updatePages() {
  const px = state.camera.position.x;
  const pz = state.camera.position.z;
  for (const p of state.pages) {
    if (p.collected) continue;
    const d = Math.hypot(p.x - px, p.z - pz);
    if (d < 1.2) {
      p.collected = true;
      state.scene.remove(p.mesh);
      state.scene.remove(p.light);
      state.collected += 1;
      setPages(state.collected, PAGES_TOTAL);
      state.audio.pickup();
      const msgs = [
        "СТРАНИЦА... осталось ещё",
        "ОН ЗНАЕТ ЧТО ТЫ ВЗЯЛ ЕЁ",
        "ТЫ СЛЫШИШЬ ШАГИ?",
        "БЕГИ",
        "ПОСЛЕДНЯЯ",
      ];
      const m = state.collected <= msgs.length ? msgs[state.collected - 1] : "СТРАНИЦА";
      showMessage(m);
      // Make monster scarier
      state.audio.stinger();
      staticBurst(0.5, 250);
      shakeScreen();

      // First page also spawns monster nearby
      if (state.collected === 1) {
        state.monster.mesh.visible = true;
        showMessage("кто-то здесь...", 3200);
      }

      if (state.collected >= PAGES_TOTAL) {
        triggerWin();
      }
    } else {
      // Slight wobble
      p.mesh.position.y = 1.3 + Math.sin(performance.now() / 800 + p.x) * 0.04;
    }
  }
}

function updateMonsterAndScares(dt) {
  if (!state.monster) return;
  const isVisible = isMonsterInView(state.camera, state.monster, state.walls);
  const caught = updateMonster(
    state.monster,
    { x: state.camera.position.x, z: state.camera.position.z },
    state.walls,
    dt,
    state.collected,
    isVisible
  );
  if (caught) {
    triggerJumpscareAndDeath();
  }
}

function updateFlashlight(dt) {
  if (!state.flashlightOn) return;
  // Flicker more as monster is closer
  const d = monsterDistance();
  const flickerProb = d < 6 ? 0.04 : d < 12 ? 0.008 : 0;
  state.flashlightFlickerTimer -= dt;
  if (state.flashlightFlickerTimer <= 0 && Math.random() < flickerProb) {
    state.flashlight.intensity = 1.5;
    state.flashlightFlickerTimer = 0.08 + Math.random() * 0.12;
  } else if (state.flashlightFlickerTimer <= 0) {
    state.flashlight.intensity = 14;
  }
}

function monsterDistance() {
  if (!state.monster || !state.monster.mesh.visible) return 999;
  return Math.hypot(
    state.camera.position.x - state.monster.mesh.position.x,
    state.camera.position.z - state.monster.mesh.position.z
  );
}

function updateAudioState(dt) {
  // Heartbeat intensifies as monster approaches
  const d = monsterDistance();
  const i = d > 18 ? 0 : Math.max(0, 1 - (d - 1.5) / 16);
  state.audio.setHeartbeatIntensity(i);
  state.audio.updateHeartbeat(dt);

  // Whispers scale with collected pages
  const wInt = Math.min(1, state.collected / PAGES_TOTAL + i * 0.3);
  state.audio.setWhisperIntensity(wInt);
  state.audio.updateWhispers(dt);
}

function triggerMiniScare() {
  // Quick flash + stinger + static
  state.audio.stinger();
  staticBurst(0.8, 280);
  flashOverlay(0.9);
  shakeScreen();
  state.cameraShake = 1.0;
  // Maybe spawn monster behind player briefly
  const dir = new THREE.Vector3();
  state.camera.getWorldDirection(dir);
  const behind = state.camera.position.clone().sub(dir.multiplyScalar(3.5));
  state.monster.mesh.visible = true;
  state.monster.mesh.position.set(behind.x, 0, behind.z);
  // It will retreat (since it teleports when seen) — fine
  showMessage("...за спиной...");
}

function triggerJumpscareAndDeath() {
  if (state.gameOver) return;
  state.gameOver = true;
  state.audio.scream();
  staticBurst(1.0, 1500);
  drawJumpscare();
  state.jumpscareUntil = performance.now() + 1500;
  setTimeout(() => {
    showGameOver(state.collected, PAGES_TOTAL, false);
    hideJumpscare();
    state.controls.unlock();
  }, 1700);
}

function triggerWin() {
  state.gameOver = true;
  state.win = true;
  showMessage("ВЫХОД...", 4000);
  // Brief stinger + win screen after a short pause
  setTimeout(() => {
    flashOverlay(0.9);
    state.audio.stinger();
    setTimeout(() => {
      showGameOver(state.collected, PAGES_TOTAL, true);
      state.controls.unlock();
    }, 600);
  }, 2000);
}
