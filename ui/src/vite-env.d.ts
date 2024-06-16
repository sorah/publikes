/// <reference types="vite/client" />
interface ImportMetaEnv {
  readonly VITE_DATA_URL: string;
  readonly VITE_HTML_TITLE: string;
  readonly VITE_HTML_LANG: string;
  readonly VITE_APP_LANG: string;
}
interface ImportMeta {
  readonly env: ImportMetaEnv;
}
