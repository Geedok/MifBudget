// Génère les images Android du logo MifBudget (icônes et écran de
// chargement) à partir des SVG de ce dossier.
//
//   NODE_PATH=$(npm root -g) node tool/logo/render.js
//
// Nécessite Playwright et Chromium.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const here = __dirname;
const res = path.join(here, '../../android/app/src/main/res');
const fonts = path.join(here, '../../assets/fonts');
const svg = (name) => fs.readFileSync(path.join(here, name), 'utf8');

const densities = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };

// Page HTML de `px` pixels contenant `body`.
const page = (px, body, h = px) => `<!doctype html><html><head><style>
@font-face{font-family:Inter;font-weight:700;src:url(file://${fonts}/Inter-Bold.ttf)}
@font-face{font-family:Inter;font-weight:400;src:url(file://${fonts}/Inter-Regular.ttf)}
html,body{margin:0;background:transparent;width:${px}px;height:${h}px;overflow:hidden}
svg{display:block;width:${px}px;height:${px}px}
</style></head><body>${body}</body></html>`;

const clip = (radius, content) =>
  `<div style="width:100%;height:100%;border-radius:${radius};overflow:hidden">${content}</div>`;

(async () => {
  const browser = await chromium.launch();
  const tab = await browser.newPage();
  async function shot(file, w, h, html) {
    await tab.setViewportSize({ width: w, height: h });
    await tab.setContent(html);
    await tab.evaluate(() => document.fonts.ready);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    await tab.screenshot({ path: file, omitBackground: true });
  }

  for (const [name, d] of Object.entries(densities)) {
    const mip = path.join(res, `mipmap-${name}`);
    const draw = path.join(res, `drawable-${name}`);
    // Icônes classiques (Android 7) : 48 dp.
    const legacy = Math.round(48 * d);
    await shot(path.join(mip, 'ic_launcher.png'), legacy, legacy,
      page(legacy, clip('22%', svg('icon.svg'))));
    await shot(path.join(mip, 'ic_launcher_round.png'), legacy, legacy,
      page(legacy, clip('50%', svg('icon.svg'))));
    // Icône adaptative (Android 8+) : calques de 108 dp.
    const layer = Math.round(108 * d);
    for (const l of ['background', 'foreground', 'monochrome']) {
      await shot(path.join(mip, `ic_launcher_${l}.png`), layer, layer,
        page(layer, svg(`${l}.svg`)));
    }
    // Écran de chargement avant Android 12 : logo rond de 128 dp.
    const logo = Math.round(128 * d);
    await shot(path.join(draw, 'splash_logo.png'), logo, logo,
      page(logo, clip('50%', svg('icon.svg'))));
    // Nom en bas de l'écran de chargement : 200 × 80 dp.
    const bw = Math.round(200 * d);
    const bh = Math.round(80 * d);
    await shot(path.join(draw, 'splash_branding.png'), bw, bh, page(bw, `
      <div style="height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;font-family:Inter;color:#fff">
        <div style="font-weight:700;font-size:${22 * d}px;letter-spacing:${0.3 * d}px">MifBudget</div>
        <div style="font-weight:400;font-size:${13 * d}px;opacity:.72;margin-top:${3 * d}px">Le budget du foyer</div>
      </div>`, bh));
  }
  await browser.close();
})();
