// 构建：把图标以 base64 内嵌进单文件 HTML
// 用法示例：
//   node src/build.js --template src/template.html --no-icon --out index.html
//   node _src/build.js --template _src/template.html --icon _assets/wechat-icon-384.png --out 微信聊天弹窗生成器.html
const fs = require('fs');
const path = require('path');

const argv = process.argv.slice(2);
const hasFlag = name => argv.includes('--' + name);
function opt(name, def){
  const i = argv.indexOf('--' + name);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : def;
}

const tplPath  = path.resolve(opt('template', '_src/template.html'));
const outPath  = path.resolve(opt('out', '微信聊天弹窗生成器.html'));
const noIcon   = hasFlag('no-icon');
const iconPath = path.resolve(opt('icon', '_assets/wechat-icon-384.png'));

const PLACEHOLDER = '__WECHAT_ICON_DATAURI__';

if (!fs.existsSync(tplPath)){
  console.error('模板不存在: ' + tplPath);
  process.exit(1);
}
const tpl = fs.readFileSync(tplPath, 'utf8');
if (!tpl.includes(PLACEHOLDER)){
  console.error('模板缺少占位符 ' + PLACEHOLDER);
  process.exit(1);
}

let dataUri = '';
if (!noIcon){
  if (!fs.existsSync(iconPath)){
    console.error('图标不存在: ' + iconPath + '（如需不含图标，用 --no-icon）');
    process.exit(1);
  }
  dataUri = 'data:image/png;base64,' + fs.readFileSync(iconPath).toString('base64');
}

const out = tpl.split(PLACEHOLDER).join(dataUri);
fs.writeFileSync(outPath, out, 'utf8');
console.log('built: ' + outPath);
console.log('  icon : ' + (noIcon ? '不含图标（用户自行上传）' : iconPath + ' -> ' + dataUri.length + ' chars'));
console.log('  size : ' + fs.statSync(outPath).size + ' bytes');
