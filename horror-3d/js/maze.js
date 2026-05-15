import * as THREE from "https://esm.sh/three@0.160.0";

// Recursive backtracker maze on a CELL_X x CELL_Z grid.
// Each cell is CELL_SIZE world units. Walls are placed on cell edges.
export const CELL_SIZE = 6;
export const CELLS_X = 14;
export const CELLS_Z = 14;
export const WALL_HEIGHT = 4.5;

function makeGrid(w, h) {
  const cells = new Array(w * h);
  for (let i = 0; i < cells.length; i++) {
    cells[i] = { x: 0, z: 0, walls: { n: true, s: true, e: true, w: true }, visited: false };
  }
  for (let z = 0; z < h; z++) {
    for (let x = 0; x < w; x++) {
      const c = cells[z * w + x];
      c.x = x; c.z = z;
    }
  }
  return cells;
}

function neighbors(cells, x, z, w, h) {
  const out = [];
  if (z > 0)     out.push({ dir: "n", cell: cells[(z - 1) * w + x] });
  if (z < h - 1) out.push({ dir: "s", cell: cells[(z + 1) * w + x] });
  if (x < w - 1) out.push({ dir: "e", cell: cells[z * w + (x + 1)] });
  if (x > 0)     out.push({ dir: "w", cell: cells[z * w + (x - 1)] });
  return out.filter((n) => !n.cell.visited);
}

function opposite(d) { return { n: "s", s: "n", e: "w", w: "e" }[d]; }

export function generateMaze(seed = Math.random()) {
  // Simple LCG seeded random for repeatable layouts within a session
  let s = Math.floor(seed * 2 ** 31);
  const rand = () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 2 ** 32; };

  const cells = makeGrid(CELLS_X, CELLS_Z);
  const stack = [];
  const start = cells[0];
  start.visited = true;
  stack.push(start);
  while (stack.length) {
    const c = stack[stack.length - 1];
    const ns = neighbors(cells, c.x, c.z, CELLS_X, CELLS_Z);
    if (!ns.length) { stack.pop(); continue; }
    const next = ns[Math.floor(rand() * ns.length)];
    c.walls[next.dir] = false;
    next.cell.walls[opposite(next.dir)] = false;
    next.cell.visited = true;
    stack.push(next.cell);
  }

  // Knock out additional walls to create loops (less dead-endy, scarier)
  const extra = Math.floor(CELLS_X * CELLS_Z * 0.08);
  for (let i = 0; i < extra; i++) {
    const x = Math.floor(rand() * CELLS_X);
    const z = Math.floor(rand() * CELLS_Z);
    const dirs = ["n", "s", "e", "w"];
    const dir = dirs[Math.floor(rand() * 4)];
    const c = cells[z * CELLS_X + x];
    if (dir === "n" && z > 0) { c.walls.n = false; cells[(z - 1) * CELLS_X + x].walls.s = false; }
    if (dir === "s" && z < CELLS_Z - 1) { c.walls.s = false; cells[(z + 1) * CELLS_X + x].walls.n = false; }
    if (dir === "e" && x < CELLS_X - 1) { c.walls.e = false; cells[z * CELLS_X + (x + 1)].walls.w = false; }
    if (dir === "w" && x > 0) { c.walls.w = false; cells[z * CELLS_X + (x - 1)].walls.e = false; }
  }

  return cells;
}

function cellCenter(x, z) {
  return new THREE.Vector3(x * CELL_SIZE + CELL_SIZE / 2, 0, z * CELL_SIZE + CELL_SIZE / 2);
}

// Builds floor, ceiling, walls. Returns { group, walls: AABB list, bounds, pageSpots }
export function buildMazeMesh(cells, scene) {
  const group = new THREE.Group();
  scene.add(group);

  const WORLD_W = CELLS_X * CELL_SIZE;
  const WORLD_D = CELLS_Z * CELL_SIZE;

  // Textures (procedural via canvas) ---------------------------------------
  const floorTex = makeNoiseTexture(512, "#1a1410", "#08060a", 0.18);
  floorTex.repeat.set(CELLS_X, CELLS_Z);
  const wallTex = makeWallTexture();
  wallTex.repeat.set(1, 1);
  const ceilTex = makeNoiseTexture(256, "#0a0808", "#000", 0.3);
  ceilTex.repeat.set(CELLS_X, CELLS_Z);

  const floorMat = new THREE.MeshStandardMaterial({ map: floorTex, roughness: 0.95, metalness: 0.0 });
  const ceilMat  = new THREE.MeshStandardMaterial({ map: ceilTex, roughness: 1.0, metalness: 0.0 });
  const wallMat  = new THREE.MeshStandardMaterial({ map: wallTex, roughness: 0.92, metalness: 0.02 });

  // Floor
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(WORLD_W, WORLD_D), floorMat);
  floor.rotation.x = -Math.PI / 2;
  floor.position.set(WORLD_W / 2, 0, WORLD_D / 2);
  floor.receiveShadow = true;
  group.add(floor);

  // Ceiling
  const ceil = new THREE.Mesh(new THREE.PlaneGeometry(WORLD_W, WORLD_D), ceilMat);
  ceil.rotation.x = Math.PI / 2;
  ceil.position.set(WORLD_W / 2, WALL_HEIGHT, WORLD_D / 2);
  ceil.receiveShadow = true;
  group.add(ceil);

  // Walls
  const walls = []; // AABBs for collision
  const WALL_THICK = 0.4;
  const wallGeoH = new THREE.BoxGeometry(CELL_SIZE, WALL_HEIGHT, WALL_THICK);
  const wallGeoV = new THREE.BoxGeometry(WALL_THICK, WALL_HEIGHT, CELL_SIZE);

  for (let z = 0; z < CELLS_Z; z++) {
    for (let x = 0; x < CELLS_X; x++) {
      const c = cells[z * CELLS_X + x];
      const cx = x * CELL_SIZE + CELL_SIZE / 2;
      const cz = z * CELL_SIZE + CELL_SIZE / 2;
      if (c.walls.n) {
        const m = new THREE.Mesh(wallGeoH, wallMat);
        m.position.set(cx, WALL_HEIGHT / 2, cz - CELL_SIZE / 2);
        m.castShadow = true; m.receiveShadow = true;
        group.add(m);
        walls.push(aabb(m.position, CELL_SIZE, WALL_THICK));
      }
      if (c.walls.w) {
        const m = new THREE.Mesh(wallGeoV, wallMat);
        m.position.set(cx - CELL_SIZE / 2, WALL_HEIGHT / 2, cz);
        m.castShadow = true; m.receiveShadow = true;
        group.add(m);
        walls.push(aabb(m.position, WALL_THICK, CELL_SIZE));
      }
      // East/south walls only on borders to avoid duplicates
      if (x === CELLS_X - 1 && c.walls.e) {
        const m = new THREE.Mesh(wallGeoV, wallMat);
        m.position.set(cx + CELL_SIZE / 2, WALL_HEIGHT / 2, cz);
        m.castShadow = true; m.receiveShadow = true;
        group.add(m);
        walls.push(aabb(m.position, WALL_THICK, CELL_SIZE));
      }
      if (z === CELLS_Z - 1 && c.walls.s) {
        const m = new THREE.Mesh(wallGeoH, wallMat);
        m.position.set(cx, WALL_HEIGHT / 2, cz + CELL_SIZE / 2);
        m.castShadow = true; m.receiveShadow = true;
        group.add(m);
        walls.push(aabb(m.position, CELL_SIZE, WALL_THICK));
      }
    }
  }

  // Add a few props (broken furniture-like boxes) for variety + collision
  const propMat = new THREE.MeshStandardMaterial({ color: 0x1a1108, roughness: 1.0 });
  const propCount = Math.floor(CELLS_X * CELLS_Z * 0.07);
  for (let i = 0; i < propCount; i++) {
    const cx = Math.floor(Math.random() * CELLS_X);
    const cz = Math.floor(Math.random() * CELLS_Z);
    const w = 0.8 + Math.random() * 1.2;
    const h = 0.6 + Math.random() * 1.6;
    const d = 0.8 + Math.random() * 1.2;
    const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), propMat);
    const c = cellCenter(cx, cz);
    m.position.set(
      c.x + (Math.random() - 0.5) * (CELL_SIZE - w - 1),
      h / 2,
      c.z + (Math.random() - 0.5) * (CELL_SIZE - d - 1)
    );
    m.castShadow = true; m.receiveShadow = true;
    group.add(m);
    walls.push(aabb(m.position, w, d));
  }

  // Choose page spots: pick cells that are far apart
  const pageSpots = pickPageSpots(cells);

  return {
    group, walls,
    bounds: { minX: 0, minZ: 0, maxX: WORLD_W, maxZ: WORLD_D },
    pageSpots,
    cellCenter,
  };
}

function aabb(pos, sizeX, sizeZ) {
  return {
    minX: pos.x - sizeX / 2 - 0.05,
    maxX: pos.x + sizeX / 2 + 0.05,
    minZ: pos.z - sizeZ / 2 - 0.05,
    maxZ: pos.z + sizeZ / 2 + 0.05,
  };
}

function pickPageSpots(cells) {
  // Want 5 spots spread out across the maze.
  // The player spawns at cell (0,0); we keep pages at least 3 cells away
  // from spawn so they aren't picked up the instant the game starts.
  const total = 5;
  const spots = [];
  const candidates = cells
    .map((c) => ({ x: c.x, z: c.z }))
    .filter((c) => Math.hypot(c.x, c.z) >= 3);
  // First spot: cell furthest from origin
  candidates.sort((a, b) => (b.x + b.z) - (a.x + a.z));
  spots.push(candidates[0]);
  // Then greedily pick spots that maximize minimum distance to existing spots
  while (spots.length < total) {
    let best = null, bestD = -1;
    for (const c of candidates) {
      if (spots.some((s) => s.x === c.x && s.z === c.z)) continue;
      let minD = Infinity;
      for (const s of spots) {
        const d = Math.hypot(c.x - s.x, c.z - s.z);
        if (d < minD) minD = d;
      }
      if (minD > bestD) { bestD = minD; best = c; }
    }
    spots.push(best);
  }
  return spots.map((s) => cellCenter(s.x, s.z));
}

function makeNoiseTexture(size, c1, c2, amount) {
  const cv = document.createElement("canvas");
  cv.width = cv.height = size;
  const ctx = cv.getContext("2d");
  ctx.fillStyle = c1;
  ctx.fillRect(0, 0, size, size);
  const img = ctx.getImageData(0, 0, size, size);
  for (let i = 0; i < img.data.length; i += 4) {
    if (Math.random() < amount) {
      img.data[i + 0] = 8 + Math.random() * 30;
      img.data[i + 1] = 6 + Math.random() * 20;
      img.data[i + 2] = 6 + Math.random() * 16;
    }
  }
  ctx.putImageData(img, 0, 0);
  // Smudges
  for (let i = 0; i < 16; i++) {
    ctx.fillStyle = `rgba(0,0,0,${0.05 + Math.random() * 0.1})`;
    ctx.beginPath();
    ctx.arc(Math.random() * size, Math.random() * size, 20 + Math.random() * 80, 0, Math.PI * 2);
    ctx.fill();
  }
  const tex = new THREE.CanvasTexture(cv);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

function makeWallTexture() {
  const size = 512;
  const cv = document.createElement("canvas");
  cv.width = cv.height = size;
  const ctx = cv.getContext("2d");
  // Base
  const g = ctx.createLinearGradient(0, 0, 0, size);
  g.addColorStop(0, "#1d1815");
  g.addColorStop(1, "#0c0908");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, size, size);
  // Plank/peeling wallpaper effect
  for (let i = 0; i < 200; i++) {
    ctx.fillStyle = `rgba(${20 + Math.random()*20}, ${15 + Math.random()*15}, ${10 + Math.random()*10}, 0.6)`;
    ctx.fillRect(Math.random() * size, Math.random() * size, 1 + Math.random() * 3, 30 + Math.random() * 200);
  }
  // Dark stains
  for (let i = 0; i < 8; i++) {
    ctx.fillStyle = `rgba(20, 0, 0, ${0.1 + Math.random() * 0.25})`;
    ctx.beginPath();
    ctx.ellipse(Math.random() * size, Math.random() * size, 40 + Math.random() * 90, 60 + Math.random() * 120, Math.random() * Math.PI, 0, Math.PI * 2);
    ctx.fill();
  }
  // Cracks
  ctx.strokeStyle = "rgba(0,0,0,0.5)";
  ctx.lineWidth = 1;
  for (let i = 0; i < 12; i++) {
    ctx.beginPath();
    let x = Math.random() * size, y = Math.random() * size;
    ctx.moveTo(x, y);
    for (let j = 0; j < 6; j++) {
      x += (Math.random() - 0.5) * 80;
      y += (Math.random() - 0.5) * 80;
      ctx.lineTo(x, y);
    }
    ctx.stroke();
  }
  // Scratched message (subtle)
  ctx.fillStyle = "rgba(120, 10, 10, 0.18)";
  ctx.font = "bold 28px serif";
  const msgs = ["НЕ ОБОРАЧИВАЙСЯ", "ОН ВИДИТ", "БЕГИ", "ПОМОГИТЕ"];
  ctx.fillText(msgs[Math.floor(Math.random() * msgs.length)], 40 + Math.random() * 100, 80 + Math.random() * 380);

  const tex = new THREE.CanvasTexture(cv);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

// Returns true if circle at (x,z) radius r collides with any wall
export function collides(walls, x, z, r) {
  for (const w of walls) {
    const cx = Math.max(w.minX, Math.min(x, w.maxX));
    const cz = Math.max(w.minZ, Math.min(z, w.maxZ));
    const dx = x - cx, dz = z - cz;
    if (dx * dx + dz * dz < r * r) return true;
  }
  return false;
}

// Resolve player movement against walls. Returns new (x,z).
export function moveAndCollide(walls, x, z, dx, dz, r) {
  let nx = x + dx;
  if (collides(walls, nx, z, r)) nx = x;
  let nz = z + dz;
  if (collides(walls, nx, nz, r)) nz = z;
  return { x: nx, z: nz };
}
