import { build } from 'esbuild';
import { copyFile, mkdir, readFile, writeFile } from 'node:fs/promises';

await mkdir('dist', { recursive: true });
const worker = await build({
  entryPoints: ['node_modules/monaco-editor/esm/vs/editor/editor.worker.js'],
  bundle: true, format: 'iife', write: false, minify: true,
});
await build({
  entryPoints: ['editor.js'],
  bundle: true, format: 'iife', outfile: 'dist/editor.js', target: 'safari18',
  minify: true, loader: { '.ttf': 'dataurl' },
  define: { EDITOR_WORKER: JSON.stringify(worker.outputFiles[0].text) },
  plugins: [{
    name: 'textmate-grammars',
    setup(builder) {
      const ids = 'javascript jsx typescript tsx python swift zig go rust toml yaml json jsonc markdown shellscript html css sql c cpp java ruby diff'.split(' ');
      builder.onResolve({ filter: /^senterm-grammars$/ }, () => ({ path: 'grammars', namespace: 'senterm' }));
      builder.onLoad({ filter: /.*/, namespace: 'senterm' }, () => ({
        resolveDir: process.cwd(),
        contents: 'export default [' + ids.map(id => 'import("@shikijs/langs/' + id + '")').join(',') + ']',
        loader: 'js',
      }));
    },
  }],
});
for (const name of ['index.html', 'review.css']) await copyFile(name, 'dist/' + name);
const notices = [
  'vscode-license.txt',
  'node_modules/monaco-editor/LICENSE',
  'node_modules/monaco-editor/ThirdPartyNotices.txt',
  'node_modules/shiki/LICENSE',
  ...['monaco', 'langs', 'engine-oniguruma', 'core', 'types', 'primitive'].map(
    name => 'node_modules/@shikijs/' + name + '/LICENSE'),
  'node_modules/@shikijs/vscode-textmate/LICENSE.md',
];
const parts = await Promise.all(notices.map(async name => name + '\n\n' + await readFile(name, 'utf8')));
await writeFile('dist/licenses.txt', parts.join('\n\n'));
