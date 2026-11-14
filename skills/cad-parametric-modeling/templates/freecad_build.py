"""<部品の名前> のパラメトリックな設計（FreeCAD の雛形）。

この雛形は、設計の正本にするスクリプトの骨組み。形状（build_shape）と検査の値は案件に合わせて書き換える。
例の形状は、穴の開いた円柱（差し込みのソケットを持つ部品の例）。

座標系と単位:
- 単位は mm。Z が上。Z = 0 を造形の底面（ビルドプレートに置く面）にする。
- 原点は底面の中心。

流し方:
  freecadcmd <このファイル>
    - out/ に .FCStd・.step・.stl・断面の SVG を書き、検査に落ちたら 0 でない値で終わる。
    - GUI の状態（表示とカメラ）は、freecad をオフスクリーンで起こして書き足す（freecad が無ければ飛ばして、その旨を表示する）。
"""

from __future__ import annotations

import math
import os
from pathlib import Path
import shutil
import subprocess
import sys

import FreeCAD as App
import MeshPart
import Part


# ==============================================================================
# パラメータ（値の根拠は、案件の一次情報の記録の項目の識別子で書く）
#   根拠の書き方: SRC-xx（確認済み） / SRC-xx（未確認・仮置き） / 実測（日付・道具） / 設計の判断
# ==============================================================================
PARAMS = {
    # 差し込む相手の外径 [mm]（SRC-01（未確認・仮置き）: 実測待ち）
    "insert_diameter_mm": 18.0,
    # 差し込みのすきま [mm]（設計の判断: 素材と造形の精度で決める。試作で実測して直す）
    "insert_clearance_mm": 0.3,
    # 差し込みの深さ [mm]（SRC-02（確認済み））
    "socket_depth_mm": 30.0,
    # 底の厚み [mm]（設計の判断）
    "bottom_thickness_mm": 8.0,
    # 外径 [mm]（設計の判断）
    "outer_diameter_mm": 30.0,

    # --- 検査の値（案件の制約から写す。根拠を書く） ---
    # 最小の肉厚 [mm]（設計の判断: ノズル径と壁の周回数から）
    "min_wall_mm": 2.0,
    # 造形できる大きさの上限 [mm]（案件の制約。例: プリンタの造形範囲）
    "build_volume_xyz_mm": (180.0, 180.0, 180.0),

    # --- メッシュの細かさ ---
    "mesh_linear_deflection_mm": 0.05,
    "mesh_angular_deflection_rad": 0.2,
}

PART_LABEL = "Part"  # ドキュメントの中の部品の名前
OUT_STEM = "part"    # 書き出すファイルの名前の元


# ==============================================================================
# 事前の検査（形状を作る前に、値の組み合わせが成り立つかを見る）
# ==============================================================================
def validate_params(p: dict) -> None:
    errors = []
    socket_d = p["insert_diameter_mm"] + p["insert_clearance_mm"]
    wall = (p["outer_diameter_mm"] - socket_d) / 2.0
    if p["insert_clearance_mm"] < 0:
        errors.append("insert_clearance_mm が負")
    if wall < p["min_wall_mm"]:
        errors.append(f"側面の肉厚 {wall:.2f} mm が最小 {p['min_wall_mm']} mm を下回る")
    if p["bottom_thickness_mm"] < p["min_wall_mm"]:
        errors.append("底の厚みが最小の肉厚を下回る")
    if errors:
        raise ValueError("パラメータの検査に落ちた: " + "; ".join(errors))


# ==============================================================================
# 形状
# ==============================================================================
def build_shape(p: dict) -> Part.Shape:
    height = p["bottom_thickness_mm"] + p["socket_depth_mm"]
    body = Part.makeCylinder(p["outer_diameter_mm"] / 2.0, height)
    socket_r = (p["insert_diameter_mm"] + p["insert_clearance_mm"]) / 2.0
    socket = Part.makeCylinder(socket_r, p["socket_depth_mm"] + 1.0,
                               App.Vector(0, 0, p["bottom_thickness_mm"]))
    return body.cut(socket)


# ==============================================================================
# 検査（作った形状と、書き出すメッシュ）
# ==============================================================================
def check_solid(shape: Part.Shape, p: dict) -> list[str]:
    errors = []
    if shape.isNull():
        return ["形状が空"]
    if not shape.isValid():
        errors.append("B-Rep が正しくない（isValid が偽）")
    if len(shape.Solids) != 1:
        errors.append(f"ソリッドが {len(shape.Solids)} 個（1 個であること）")
    elif not shape.Solids[0].isClosed():
        errors.append("ソリッドが閉じていない")
    bb = shape.BoundBox
    lim = p["build_volume_xyz_mm"]
    if bb.XLength > lim[0] or bb.YLength > lim[1] or bb.ZLength > lim[2]:
        errors.append(f"外形 {bb.XLength:.1f}×{bb.YLength:.1f}×{bb.ZLength:.1f} mm が造形の上限を超える")
    if abs(bb.ZMin) > 1e-6:
        errors.append(f"底面が Z = 0 に無い（ZMin = {bb.ZMin:.4f}）")
    return errors


def check_mesh(mesh) -> list[str]:
    errors = []
    if not mesh.isSolid():
        errors.append("メッシュが閉じていない（isSolid が偽）")
    if mesh.hasNonManifolds():
        errors.append("メッシュに非多様体がある")
    if mesh.hasSelfIntersections():
        errors.append("メッシュに自己交差がある")
    return errors


# ==============================================================================
# 断面のプレビュー（追加の部品を使わず、断面の線を SVG に書く）
# ==============================================================================
def write_section_svg(shape: Part.Shape, path: Path, scale: float = 4.0) -> None:
    """Y = 0 の面（XZ 面）で切った断面の輪郭を SVG にする。寸法は外形だけを書く。"""
    wires = shape.slice(App.Vector(0, 1, 0), 0.0)
    bb = shape.BoundBox
    margin = 10.0
    w = (bb.XLength + 2 * margin) * scale
    h = (bb.ZLength + 2 * margin) * scale

    def tx(v):  # 模型の座標 → SVG の座標（Z を上に）
        return ((v.x - bb.XMin + margin) * scale, (bb.ZMax - v.z + margin) * scale)

    paths = []
    for wire in wires:
        pts = wire.discretize(Deflection=0.02)
        d = " ".join(("M" if i == 0 else "L") + f"{x:.2f},{y:.2f}"
                     for i, (x, y) in enumerate(tx(q) for q in pts))
        paths.append(f'<path d="{d} Z" fill="#cfe3f0" stroke="#1d4f73" stroke-width="1"/>')
    label = f"断面 Y=0 / 外形 X {bb.XLength:.2f} mm × Z {bb.ZLength:.2f} mm"
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:.0f}" height="{h + 24:.0f}">'
        f'<rect width="100%" height="100%" fill="white"/>'
        + "".join(paths)
        + f'<text x="8" y="{h + 16:.0f}" font-size="14" font-family="sans-serif">{label}</text></svg>'
    )
    path.write_text(svg, encoding="utf-8")


# ==============================================================================
# GUI の状態（freecadcmd だけで保存すると GuiDocument.xml が入らず、GUI で開くと表示が切れている）
# ==============================================================================
def isometric_camera(bb) -> str:
    """外形の箱が収まる斜めからの正射影のカメラ（Coin3D の文字列）。"""
    cx, cy, cz = bb.Center.x, bb.Center.y, bb.Center.z
    diag = max(bb.DiagonalLength, 10.0)
    focal = diag * 1.6
    d = focal / math.sqrt(3.0)
    return (
        "#Inventor V2.1 ascii\n"
        "OrthographicCamera {\n"
        "  viewportMapping ADJUST_CAMERA\n"
        f"  position {cx + d:.4f} {cy - d:.4f} {cz + d:.4f}\n"
        "  orientation 0.7429058 0.30772194 0.59447289 1.2171202\n"
        f"  nearDistance {max(0.5, focal * 0.05):.4f}\n"
        f"  farDistance {focal * 4.0:.4f}\n"
        "  aspectRatio 1\n"
        f"  focalDistance {focal:.4f}\n"
        f"  height {diag * 0.95:.4f}\n"
        "}\n"
    )


def save_gui_state_offscreen(fcstd: Path, visible: list[str], hidden: list[str], cam: str) -> str:
    freecad_bin = shutil.which("freecad")
    if not freecad_bin:
        return "飛ばした（freecad が見つからない）"
    script = (
        "import FreeCAD as App, FreeCADGui as Gui\n"
        "Gui.showMainWindow()\n"
        f"doc = App.openDocument({str(fcstd)!r})\n"
        f"for n in {visible!r}:\n"
        "    o = doc.getObject(n)\n"
        "    if o is not None: o.ViewObject.Visibility = True\n"
        f"for n in {hidden!r}:\n"
        "    o = doc.getObject(n)\n"
        "    if o is not None: o.ViewObject.Visibility = False\n"
        "Gui.ActiveDocument.ActiveView.setCamera(" + repr(cam) + ")\n"
        f"doc.saveAs({str(fcstd)!r})\n"
    )
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen")
    res = subprocess.run([freecad_bin, "-c", script], env=env, stdin=subprocess.DEVNULL,
                         capture_output=True, text=True, timeout=120, check=False)
    return "書いた" if res.returncode == 0 else f"失敗（終了コード {res.returncode}）"


# ==============================================================================
# 書き出し
# ==============================================================================
def add_params_sheet(doc, p: dict) -> None:
    """パラメータを GUI で見られる表にする。数値の行には別名を付け、式から参照できるようにする。"""
    sheet = doc.addObject("Spreadsheet::Sheet", "Params")
    sheet.set("A1", "parameter")
    sheet.set("B1", "value")
    for row, (key, val) in enumerate(p.items(), start=2):
        sheet.set(f"A{row}", key)
        sheet.set(f"B{row}", str(val))
        if isinstance(val, (int, float)):
            sheet.setAlias(f"B{row}", key)


def main() -> int:
    out_dir = Path(__file__).resolve().parent / "out"
    out_dir.mkdir(parents=True, exist_ok=True)

    validate_params(PARAMS)
    shape = build_shape(PARAMS)

    errors = check_solid(shape, PARAMS)
    mesh = MeshPart.meshFromShape(Shape=shape,
                                  LinearDeflection=PARAMS["mesh_linear_deflection_mm"],
                                  AngularDeflection=PARAMS["mesh_angular_deflection_rad"],
                                  Relative=False)
    errors += check_mesh(mesh)
    if errors:
        print("検査に落ちた:\n  - " + "\n  - ".join(errors), flush=True)
        return 1

    doc = App.newDocument("Build")
    obj = doc.addObject("Part::Feature", PART_LABEL)
    obj.Shape = shape
    add_params_sheet(doc, PARAMS)
    doc.recompute()

    fcstd = out_dir / f"{OUT_STEM}.FCStd"
    step = out_dir / f"{OUT_STEM}.step"
    stl = out_dir / f"{OUT_STEM}.stl"
    svg = out_dir / f"{OUT_STEM}_section.svg"
    doc.saveAs(str(fcstd))
    Part.export([obj], str(step))
    mesh.write(str(stl))
    write_section_svg(shape, svg)
    App.closeDocument(doc.Name)

    gui = "GUI の中で流したので不要" if App.GuiUp else save_gui_state_offscreen(
        fcstd, [PART_LABEL], ["Params"], isometric_camera(shape.BoundBox))

    bb = shape.BoundBox
    print("=== 組み立ての結果 ===")
    print(f"外形 (mm)      : X={bb.XLength:.2f} Y={bb.YLength:.2f} Z={bb.ZLength:.2f}")
    print(f"体積 (cm^3)    : {shape.Volume / 1000.0:.2f}")
    print(f"ソリッド       : 正しい={shape.isValid()} 個数={len(shape.Solids)} 閉じている={shape.Solids[0].isClosed()}")
    print(f"メッシュ       : 面={mesh.CountFacets} 閉じている={mesh.isSolid()} "
          f"非多様体={mesh.hasNonManifolds()} 自己交差={mesh.hasSelfIntersections()}")
    print(f"GUI の状態     : {gui}")
    for f in (fcstd, step, stl, svg):
        print(f"書き出し       : {f.name}")
    return 0


def _invoked_by_freecadcmd() -> bool:
    """freecadcmd <file> で流すと __name__ が __main__ にならないので、引数で見分ける。"""
    me = Path(__file__).resolve()
    return any(not a.startswith("-") and Path(a).resolve() == me for a in sys.argv[1:])


if __name__ == "__main__":
    sys.exit(main())
elif _invoked_by_freecadcmd():
    # freecadcmd では、例外で止まっても終わりの値が 0 になる。例外を拾って 0 でない値で終える。
    # sys.exit の前に出力を流しておかないと、表示が失われる。
    try:
        rc = main()
    except Exception as exc:  # 検査の失敗（ValueError など）を含めて止める
        print(f"止めた: {type(exc).__name__}: {exc}", flush=True)
        rc = 1
    sys.stdout.flush()
    if rc:
        sys.exit(rc)
