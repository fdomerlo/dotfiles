import QtQuick
import QtQuick.Shapes

// Esquina cóncava (invertida) vectorial estilo Caelestia para fundir popouts
// y drawers con la barra superior sin bordes duros ni huecos.
//
// `position` indica los dos bordes sólidos del triángulo cóncavo:
//   - "top-right": borde superior + derecho (va a la IZQUIERDA de un popout superior)
//   - "top-left" : borde superior + izquierdo (va a la DERECHA de un popout superior)
//   - "bottom-left" / "bottom-right": variantes inferiores
Item {
    id: corner
    z: 2

    property int size: Theme.concaveRadius
    property color color: Theme.surface
    property string position: "top-left"
    property int borderWidth: 0
    property color borderColor: "transparent"

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        rotation: {
            if (corner.position === "top-right")
                return 90;
            if (corner.position === "bottom-right")
                return 180;
            if (corner.position === "bottom-left")
                return 270;
            return 0;
        }

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: corner.color
            Behavior on fillColor { ColorAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
            startX: 0
            startY: 0

            PathLine {
                x: corner.size
                y: 0
            }
            PathArc {
                x: 0
                y: corner.size
                radiusX: corner.size
                radiusY: corner.size
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: 0
                y: 0
            }
        }

        ShapePath {
            strokeWidth: corner.borderWidth
            strokeColor: corner.borderWidth > 0 ? corner.borderColor : "transparent"
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            startX: corner.size
            startY: -corner.borderWidth / 2.0

            PathArc {
                x: -corner.borderWidth / 2.0
                y: corner.size
                radiusX: corner.size + corner.borderWidth / 2.0
                radiusY: corner.size + corner.borderWidth / 2.0
                direction: PathArc.Counterclockwise
            }
        }
    }
}
