# 大漠边疆 · 边军长枪（道具）

原创低多边形游戏道具。深棕旧木、低反光蓝灰枪头，只有一小段深色握带；不带旗穗、吊饰、贴图或外部依赖。

- `frontier_spear.glb`：Godot 可直接导入。+Y 朝枪头，(0,0,0) 为握持点；四个网格部分可作独立材质调色。
- `source/frontier_spear.blend`：可编辑 Blender 工程，+Z 朝枪头，四部分单独建模。
- `source/build_frontier_spear.py`：从几何源码重建。使用 Blender 4.3 测试：
  `blender --background --python source/build_frontier_spear.py`。

装到角色手部挂点时，优先按裸头冠身高的约 1.2 倍缩放整支道具，再调整旋转。这里的原点、长度与造型仅用于游戏画面。Blender 源文件目录不参与 Godot 资源导入。
