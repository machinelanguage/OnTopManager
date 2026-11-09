// Structural checks only. This does not compile Delphi or exercise Windows UI.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
function check(ok, message) { if (!ok) throw new Error(message); }
for (const base of ['uMain', 'uCPUAlert']) {
  const pas = read(base + '.pas');
  const dfm = read(base + '.dfm');
  const form = dfm.match(/^object \w+: (\w+)/m)[1];
  check(pas.includes('{$R *.dfm}'), base + ': missing form resource');
  for (const match of dfm.matchAll(/^\s+On\w+ = (\w+)/gm)) {
    check(pas.includes('procedure ' + form + '.' + match[1] + '('),
      base + ': missing event handler ' + match[1]);
  }
  for (const match of dfm.matchAll(/^\s+object (\w+): (\w+)/gm)) {
    check(pas.includes(match[1] + ': ' + match[2] + ';'),
      base + ': missing designer control ' + match[1]);
  }
}
for (const name of ['uMain.pas', 'uCPUWatch.pas', 'uCPUAlert.pas']) {
  const source = read(name);
  // Pascal lexer: comments do not count as literals; doubled quotes count once.
  let i = 0;
  while (i < source.length) {
    if (source.startsWith('//', i)) {
      const end = source.indexOf('\n', i); i = end < 0 ? source.length : end + 1;
    } else if (source[i] === '{') {
      const end = source.indexOf('}', i); check(end >= 0, name + ': open comment'); i = end + 1;
    } else if (source.startsWith('(*', i)) {
      const end = source.indexOf('*)', i); check(end >= 0, name + ': open comment'); i = end + 2;
    } else if (source[i] === "'") {
      let count = 0, closed = false; i++;
      while (i < source.length) {
        if (source[i] === "'") {
          if (source[i + 1] === "'") { count++; i += 2; }
          else { i++; closed = true; break; }
        } else { check(source[i] !== '\n', name + ': multiline literal'); count++; i++; }
      }
      check(closed && count <= 255, name + ': invalid/overlong literal');
    } else i++;
  }
}
for (const name of ['uCPUWatch.pas', 'uCPUAlert.pas']) {
  check(read('OnTopManager.dpr').includes("in '" + name + "'"), 'Missing project unit ' + name);
  check(read('OnTopManager.dproj').includes('Include="' + name + '"'), 'Missing IDE unit ' + name);
}
console.log('PASS: form bindings, resources, project units, Pascal literal limits');
