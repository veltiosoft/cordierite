export const landingJa = {
  meta: {
    title: 'Cordierite - macOS 用ローカル音声入力',
    description:
      'Cordierite は Apple Speech と Whisper に対応した macOS 用ローカル音声入力アプリです。',
    ogTitle: 'Cordierite - macOS 用ローカル音声入力',
  },
  siteLabel: 'macOS 用ローカル音声入力',
  intro: '話した内容を、Mac のどこにでもきれいなテキストで貼り付ける。',
  summary:
    'Cordierite は Apple Silicon Mac 向けの音声入力アプリです。ホットキーを押して英語または日本語で話すと、オンデバイスで文字起こしした結果を、今使っているアプリへ貼り付けます。',
  download: {
    title: 'ダウンロード',
    note: 'macOS 26 以上の Apple Silicon Mac が必要です。起動後は Permission Doctor からマイク、入力監視、アクセシビリティの権限を有効にしてください。',
    legal: {
      prefix: 'ダウンロードまたは利用により、',
      terms: '利用規約',
      middle: 'および',
      privacy: 'プライバシーポリシー',
      suffix: 'に同意したものとみなされます。',
    },
  },
  features: {
    title: '基本機能',
    intro: '無料版だけで、日常の短文音声入力が完結することを前提にしています。',
    items: [
      'Hold to Talk / Toggle によるホットキー音声入力（既定: Right Option）',
      'Apple Speech を既定にし、必要に応じて Whisper モデルをダウンロードして使用可能',
      '文字起こし結果を整形してカーソル位置へ貼り付け。可能な場合は文字列クリップボードも復元',
      '誤認識されやすい語を登録するユーザー辞書（無料版でも小規模な辞書を予定）',
      '前後空白の削除、句読点 spacing の調整、フィラー除去',
      'マイク、ホットキー、貼り付けの権限案内（Permission Doctor）',
    ],
  },
  security: {
    title: 'セキュリティ',
    body: '文字起こし処理はすべてオンデバイスで処理されます。アプリ内にも保存しません。',
  },
  pricing: {
    title: '無料 / Pro',
    intro:
      '基本的な音声入力、Whisper の基本利用、貼り付け、権限案内、セキュリティ修正、バグ修正は Pro 限定にしません。Pro は予定の有料プランであり、現時点では提供していません。',
    free: {
      title: '無料',
      items: [
        'Apple Speech による音声入力',
        'Whisper による基本的なローカル文字起こし',
        'Hold to Talk と Toggle',
        '英語と日本語の言語選択',
        '貼り付けと軽量テキスト整形',
        '小規模なユーザー辞書を予定',
      ],
    },
    pro: {
      title: 'Pro（予定）',
      price: '予定価格: USD 3/month',
      items: [
        '無制限のユーザー辞書',
        'アプリ別、プロジェクト別の辞書',
        '辞書の import / export',
        'Slack、Email、Markdown、GitHub Issue、Git Commit Message 向け文体プリセット',
        '言語、辞書、整形、貼り付け方法を切り替えるアプリ別プロファイル',
        '長文入力モード、音声ファイル一括文字起こし',
      ],
    },
  },
} as const;
