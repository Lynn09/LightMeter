# 项目协作约定

- 每完成一个功能点，运行相关验证后创建独立 Git commit。
- 提交信息说明实际功能或修复内容；完成汇报包含 commit hash 和对应 git log。
- 不把构建产物、Xcode 用户配置、临时截图或嵌套仓库提交到版本库。
- 推送按用户授权执行，不强制覆盖远程历史。
- 曝光计算相关改动运行 `bash scripts/test-exposure.sh`。
- 测距或相机启动相关改动运行 `bash scripts/test-rangefinder.sh`。
- 应用集成改动运行 `bash scripts/check-ios27-compatibility.sh`。
