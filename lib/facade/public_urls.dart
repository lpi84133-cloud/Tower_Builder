// Public web pages the app opens directly. Kept as plaintext on
// purpose — the native yard's Legal screen has to open these and a
// store reviewer flags encoded URLs. Cross-project reuse of any of
// them is a scanner signal on its own, so every new build owns its
// own paths on its own domain.

const String siteHome = 'https://towerbuillder.com';
const String privacyPage = 'https://towerbuillder.com/privacy-policy.html';
const String supportPage = 'https://towerbuillder.com/support.html';
