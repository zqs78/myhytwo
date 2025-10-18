const { spawn } = require('child_process');
const path = require('path');

// 定位 hy2.sh 的路径（和 index.js 同目录）
const hy2ScriptPath = path.join(__dirname, 'hy2.sh');

console.log(`[启动器] 开始执行 hy2.sh，路径：${hy2ScriptPath}`);

// 启动 hy2.sh 并实时输出日志
const hy2Process = spawn('bash', [hy2ScriptPath], {
  stdio: 'inherit', // 让脚本输出直接显示在面板日志
  shell: true
});

// 监听脚本退出（避免面板误判为崩溃）
hy2Process.on('exit', (exitCode) => {
  console.log(`[启动器] hy2.sh 退出，代码：${exitCode}`);
  // 若脚本异常退出，延迟30秒再结束，方便看日志
  if (exitCode !== 0) {
    console.log(`[启动器] 脚本异常，保持运行30秒查看日志...`);
    setTimeout(() => process.exit(exitCode), 30000);
  }
});

// 监听执行错误
hy2Process.on('error', (err) => {
  console.error(`[启动器] 执行 hy2.sh 失败：${err.message}`);
  console.log(`[启动器] 错误发生，保持运行30秒查看日志...`);
  setTimeout(() => process.exit(1), 30000);
});