// HUD + jumpscare overlay drawing.

let messageTimer = null;
export function showMessage(text, duration = 2500) {
  const el = document.getElementById("message");
  el.textContent = text;
  el.classList.add("show");
  if (messageTimer) clearTimeout(messageTimer);
  messageTimer = setTimeout(() => el.classList.remove("show"), duration);
}

export function setPages(n, max) {
  document.getElementById("pages-counter").textContent = `${n} / ${max}`;
}

export function setStamina(v) {
  document.getElementById("stamina-fill").style.width = `${Math.max(0, Math.min(1, v)) * 100}%`;
}

export function flashOverlay(strength = 1) {
  const el = document.getElementById("flash-overlay");
  el.style.transition = "opacity 0.02s";
  el.style.opacity = String(strength);
  setTimeout(() => {
    el.style.transition = "opacity 0.4s";
    el.style.opacity = "0";
  }, 60);
}

export function staticBurst(strength = 0.6, duration = 200) {
  const el = document.getElementById("static-overlay");
  el.style.opacity = String(strength);
  setTimeout(() => { el.style.opacity = "0"; }, duration);
}

export function shakeScreen() {
  const c = document.getElementById("game");
  c.classList.remove("shake");
  // Force reflow to restart animation
  void c.offsetWidth;
  c.classList.add("shake");
  setTimeout(() => c.classList.remove("shake"), 450);
}

// Big scary face on jumpscare. Drawn on canvas so we don't need image assets.
export function drawJumpscare() {
  const overlay = document.getElementById("jumpscare");
  const cv = document.getElementById("jumpscare-canvas");
  overlay.classList.remove("hidden");
  const w = cv.width = window.innerWidth;
  const h = cv.height = window.innerHeight;
  const ctx = cv.getContext("2d");

  ctx.fillStyle = "#000";
  ctx.fillRect(0, 0, w, h);

  const cx = w / 2, cy = h / 2;
  const fw = Math.min(w, h) * 0.85;
  const fh = fw * 1.3;

  // Face — pale, gaunt
  const faceGrad = ctx.createRadialGradient(cx, cy, fw * 0.1, cx, cy, fw * 0.55);
  faceGrad.addColorStop(0, "#e8e0d4");
  faceGrad.addColorStop(0.65, "#8a7e6e");
  faceGrad.addColorStop(1, "#000000");
  ctx.fillStyle = faceGrad;
  ctx.beginPath();
  ctx.ellipse(cx, cy, fw * 0.42, fh * 0.5, 0, 0, Math.PI * 2);
  ctx.fill();

  // Eye sockets — sunken black pits
  const eyeY = cy - fh * 0.08;
  const eyeDX = fw * 0.16;
  const eyeR  = fw * 0.085;
  for (const ex of [cx - eyeDX, cx + eyeDX]) {
    const g = ctx.createRadialGradient(ex, eyeY, 0, ex, eyeY, eyeR * 1.6);
    g.addColorStop(0, "#000");
    g.addColorStop(0.6, "#1a0a0a");
    g.addColorStop(1, "rgba(0,0,0,0)");
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(ex, eyeY, eyeR * 1.6, 0, Math.PI * 2);
    ctx.fill();
    // Tiny glowing pupil
    ctx.fillStyle = "#ff2222";
    ctx.beginPath();
    ctx.arc(ex + (Math.random() - 0.5) * 4, eyeY + (Math.random() - 0.5) * 4, eyeR * 0.18, 0, Math.PI * 2);
    ctx.fill();
  }

  // Mouth — wide, jagged, screaming
  const mouthY = cy + fh * 0.18;
  const mouthW = fw * 0.28;
  const mouthH = fh * 0.12;
  ctx.fillStyle = "#000";
  ctx.beginPath();
  ctx.moveTo(cx - mouthW, mouthY);
  const teeth = 14;
  for (let i = 0; i <= teeth; i++) {
    const t = i / teeth;
    const x = cx - mouthW + t * mouthW * 2;
    const y = mouthY + Math.sin(t * Math.PI) * mouthH + (i % 2 === 0 ? 4 : -4);
    ctx.lineTo(x, y);
  }
  for (let i = teeth; i >= 0; i--) {
    const t = i / teeth;
    const x = cx - mouthW + t * mouthW * 2;
    const y = mouthY - Math.sin(t * Math.PI) * mouthH * 0.8 + (i % 2 === 0 ? -4 : 4);
    ctx.lineTo(x, y);
  }
  ctx.closePath();
  ctx.fill();

  // Teeth strokes
  ctx.strokeStyle = "#bdb4a4";
  ctx.lineWidth = 2;
  ctx.beginPath();
  for (let i = 1; i < teeth; i++) {
    const t = i / teeth;
    const x = cx - mouthW + t * mouthW * 2;
    ctx.moveTo(x, mouthY - mouthH * 0.4);
    ctx.lineTo(x, mouthY + mouthH * 0.6);
  }
  ctx.stroke();

  // Blood stains
  ctx.fillStyle = "rgba(120, 0, 0, 0.55)";
  for (let i = 0; i < 50; i++) {
    const a = Math.random() * Math.PI * 2;
    const r = mouthW * (0.5 + Math.random() * 0.9);
    const x = cx + Math.cos(a) * r;
    const y = mouthY + Math.sin(a) * r * 0.4 + Math.random() * 30;
    ctx.beginPath();
    ctx.arc(x, y, 1 + Math.random() * 4, 0, Math.PI * 2);
    ctx.fill();
  }

  // Veins on face
  ctx.strokeStyle = "rgba(50, 0, 0, 0.5)";
  ctx.lineWidth = 1.2;
  for (let i = 0; i < 25; i++) {
    let x = cx + (Math.random() - 0.5) * fw * 0.7;
    let y = cy + (Math.random() - 0.5) * fh * 0.7;
    ctx.beginPath();
    ctx.moveTo(x, y);
    for (let j = 0; j < 6; j++) {
      x += (Math.random() - 0.5) * 30;
      y += (Math.random() - 0.5) * 30;
      ctx.lineTo(x, y);
    }
    ctx.stroke();
  }

  // Heavy noise/static layer
  const img = ctx.getImageData(0, 0, w, h);
  for (let i = 0; i < img.data.length; i += 4) {
    if (Math.random() < 0.15) {
      const n = Math.random() * 80 - 30;
      img.data[i + 0] = Math.min(255, Math.max(0, img.data[i + 0] + n));
      img.data[i + 1] = Math.min(255, Math.max(0, img.data[i + 1] + n));
      img.data[i + 2] = Math.min(255, Math.max(0, img.data[i + 2] + n));
    }
  }
  ctx.putImageData(img, 0, 0);

  // Vignette
  const vg = ctx.createRadialGradient(cx, cy, fw * 0.3, cx, cy, fw * 0.9);
  vg.addColorStop(0, "rgba(0,0,0,0)");
  vg.addColorStop(1, "rgba(0,0,0,1)");
  ctx.fillStyle = vg;
  ctx.fillRect(0, 0, w, h);

  // Trigger CSS shake on the overlay container too
  overlay.classList.remove("shake");
  void overlay.offsetWidth;
  overlay.classList.add("shake");
}

export function hideJumpscare() {
  document.getElementById("jumpscare").classList.add("hidden");
}

export function showGameOver(pagesCollected, total, win) {
  const el = document.getElementById("gameover");
  document.getElementById("final-pages").textContent = String(pagesCollected);
  const t = document.getElementById("gameover-title");
  const s = document.getElementById("gameover-subtitle");
  if (win) {
    t.textContent = "ТЫ ВЫШЕЛ"; t.setAttribute("data-text", "ТЫ ВЫШЕЛ");
    s.innerHTML = "ты собрал все 5 страниц. но он всё ещё рядом.";
  } else {
    t.textContent = "ОН НАШЁЛ ТЕБЯ"; t.setAttribute("data-text", "ОН НАШЁЛ ТЕБЯ");
    s.innerHTML = `страниц собрано: <span id="final-pages">${pagesCollected}</span> / ${total}`;
  }
  el.classList.remove("hidden");
}

export function hideGameOver() {
  document.getElementById("gameover").classList.add("hidden");
}

export function showHUD()  { document.getElementById("hud").classList.remove("hidden"); }
export function hideHUD()  { document.getElementById("hud").classList.add("hidden"); }
export function showIntro(){ document.getElementById("intro").classList.remove("hidden"); }
export function hideIntro(){ document.getElementById("intro").classList.add("hidden"); }
export function showPause(){ document.getElementById("pause").classList.remove("hidden"); }
export function hidePause(){ document.getElementById("pause").classList.add("hidden"); }
