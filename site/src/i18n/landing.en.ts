export const landingEn = {
  meta: {
    title: 'Cordierite - Local-first dictation for macOS',
    description:
      'Cordierite is a local-first dictation app for macOS with Apple Speech and Whisper support.',
    ogTitle: 'Cordierite - Local-first dictation for macOS',
  },
  siteLabel: 'Local-first dictation for macOS',
  intro: 'Speak once. Paste clean text anywhere on your Mac.',
  summary:
    'Cordierite is a dictation app for Apple Silicon Macs. Hold a hotkey, speak in English or Japanese, and paste the on-device transcript into the app you are already using.',
  download: {
    title: 'Download',
    note: 'Requires macOS 26 or later on Apple Silicon. After opening the app, use Permission Doctor to enable Microphone, Input Monitoring, and Accessibility permissions.',
    legal: {
      prefix: 'By downloading or using Cordierite, you agree to the ',
      terms: 'Terms of Use',
      middle: ' and acknowledge the ',
      privacy: 'Privacy Policy',
      suffix: '.',
    },
  },
  features: {
    title: 'Basic features',
    intro: 'The free app is designed for everyday short-form dictation.',
    items: [
      'Hotkey dictation with Hold to Talk or Toggle mode (default: Right Option)',
      'Apple Speech by default; download and use Whisper models as needed',
      'Paste cleaned text into the focused app and restore the text clipboard when possible',
      'User dictionary for common misrecognitions (small dictionary planned for the free plan)',
      'Light text cleanup: trim whitespace, adjust punctuation, optional filler removal',
      'Permission Doctor for microphone, hotkey, and paste setup',
    ],
  },
  security: {
    title: 'Security',
    body: 'All transcription runs on device. Nothing is stored in the app.',
  },
  pricing: {
    title: 'Free / Pro',
    intro:
      'Basic dictation, basic Whisper use, paste behavior, security fixes, and bug fixes are not planned as Pro-only features. Pro is a planned paid tier and is not available yet.',
    free: {
      title: 'Free',
      items: [
        'Apple Speech dictation',
        'Basic local Whisper transcription',
        'Hold to Talk and Toggle modes',
        'English and Japanese language selection',
        'Clipboard paste and text cleanup',
        'Small user dictionary planned for basic corrections',
      ],
    },
    pro: {
      title: 'Pro (planned)',
      price: 'Planned price: USD 3/month',
      items: [
        'Unlimited user dictionary',
        'App-specific and project-specific dictionaries',
        'Dictionary import and export',
        'Writing presets for Slack, email, Markdown, GitHub issues, and commit messages',
        'App-specific profiles for language, dictionary, formatting, and paste behavior',
        'Long-form input mode and batch audio transcription',
      ],
    },
  },
} as const;
