export const SITE = {
  name: 'Sticker Man',
  url: 'https://goofyfish.com',
  tagline: 'Silly Mini Games Arcade',
  description:
    'Silly, addictive one-tap stickman games in your pocket. 100% Free · No Wi-Fi needed.',
  twitter: '@huytrandev',
  github: 'https://github.com/huytrandevios-collab/goofyfish',
  author: { name: 'Huy Tran', url: 'https://github.com/huytrandevios-collab' },
};

export function absoluteUrl(path: string) {
  return new URL(path, SITE.url).href;
}
