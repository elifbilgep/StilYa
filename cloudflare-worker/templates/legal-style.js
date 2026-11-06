export const LEGAL_PAGE_STYLE = `
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #FAF9F6; color: #1A1A1A; line-height: 1.7; }
    .container { max-width: 720px; margin: 0 auto; padding: 48px 24px 80px; position: relative; }
    .logo { font-size: 28px; font-weight: 700; letter-spacing: -0.5px; margin-bottom: 8px; }
    .subtitle { font-size: 14px; color: #6B6B6B; margin-bottom: 48px; }
    h1 { font-size: 32px; font-weight: 700; margin-bottom: 8px; letter-spacing: -0.5px; }
    .date { font-size: 13px; color: #6B6B6B; margin-bottom: 40px; }
    h2 { font-size: 20px; font-weight: 600; margin-top: 36px; margin-bottom: 12px; }
    p, li { font-size: 15px; color: #2D2D2D; margin-bottom: 12px; }
    ul { padding-left: 20px; margin-bottom: 16px; }
    li { margin-bottom: 6px; }
    a { color: #2D2D2D; text-decoration: underline; }
    .footer { margin-top: 60px; padding-top: 24px; border-top: 1px solid #E8E6E1; font-size: 13px; color: #6B6B6B; }
    .nav { display: flex; gap: 16px; margin-top: 8px; }
    .nav a { font-size: 13px; color: #6B6B6B; }
    .lang-switch { position: absolute; top: 48px; right: 24px; display: flex; gap: 4px; background: #EEECEA; border-radius: 8px; padding: 3px; }
    .lang-switch button { border: none; background: transparent; padding: 6px 12px; font-size: 13px; font-weight: 600; color: #6B6B6B; border-radius: 6px; cursor: pointer; transition: all 0.2s; }
    .lang-switch button.active { background: #fff; color: #1A1A1A; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
    .lang-tr, .lang-en { display: none; }
    .lang-tr.visible, .lang-en.visible { display: block; }
  </style>
`;
