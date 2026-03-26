"""
WAF on CE AWS — Architecture diagram (pure matplotlib).
Generates: img-waf-on-ce-aws.png
Run from the readme/ directory:
    python3 img-waf-on-ce-aws.py
"""
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np

# ── Canvas ────────────────────────────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(22, 12))
fig.patch.set_facecolor("white")
ax.set_facecolor("white")
W, H = 22, 12
ax.set_xlim(0, W)
ax.set_ylim(0, H)
ax.axis("off")

# ── Palette ───────────────────────────────────────────────────────────────────
F5_BLUE   = "#1565C0"
F5_LITE   = "#BBDEFB"
CTRL_CLR  = "#29B6F6"   # Control plane   — light blue
DATA_CLR  = "#66BB6A"   # Client traffic  — light green
CFG_CLR   = "#1B5E20"   # Config plane    — dark green
GOLD1     = "#E65100"
GOLD2     = "#F57F17"
GOLD3     = "#F9A825"
GREEN_WAF = "#388E3C"
K8S_BLUE  = "#326CE5"
LB_BLUE   = "#1565C0"
AWS_CLR   = "#232F3E"


# ─────────────────────────────── helpers ─────────────────────────────────────

def cloud_bumps(cx, cy, w, h):
    """Return list of (bx, by, r) circles that together form a cloud."""
    return [
        (cx,          cy + h*0.20,  w*0.23),
        (cx - w*0.20, cy + h*0.09,  w*0.18),
        (cx + w*0.20, cy + h*0.09,  w*0.18),
        (cx - w*0.35, cy - h*0.01,  w*0.14),
        (cx + w*0.35, cy - h*0.01,  w*0.14),
        (cx - w*0.12, cy - h*0.03,  w*0.16),
        (cx + w*0.12, cy - h*0.03,  w*0.16),
        (cx,          cy - h*0.08,  w*0.40),   # wide base
    ]


def _cloud_mask(cx, cy, w, h, pad=0.18, nx=600, ny=420):
    """Return (X, Y, Z) raster where Z=1 inside the cloud union, 0 outside."""
    x = np.linspace(cx - w*(0.5+pad), cx + w*(0.5+pad), nx)
    y = np.linspace(cy - h*(0.5+pad), cy + h*(0.5+pad), ny)
    X, Y = np.meshgrid(x, y)
    Z = np.zeros_like(X, dtype=float)
    for bx, by, r in cloud_bumps(cx, cy, w, h):
        Z = np.maximum(Z, ((X-bx)**2 + (Y-by)**2 <= r**2).astype(float))
    return X, Y, Z


def draw_cloud(ax, cx, cy, w, h, fill="#BBDEFB", edge=F5_BLUE, lw=3, z=2):
    """Draw cloud with a single unified outer contour (no internal circle borders)."""
    X, Y, Z = _cloud_mask(cx, cy, w, h)
    ax.contourf(X, Y, Z, levels=[0.5, 2.0], colors=[fill], zorder=z)
    ax.contour (X, Y, Z, levels=[0.5], colors=[edge], linewidths=[lw], zorder=z+1)


def draw_aws_cloud(ax, cx, cy, w, h, fill="white", edge=AWS_CLR, lw=3, z=4):
    """Same as draw_cloud but styled for the AWS cloud."""
    X, Y, Z = _cloud_mask(cx, cy, w, h)
    ax.contourf(X, Y, Z, levels=[0.5, 2.0], colors=[fill], zorder=z)
    ax.contour (X, Y, Z, levels=[0.5], colors=[edge], linewidths=[lw], zorder=z+1)


def draw_re(ax, x, y, r=0.30, z=13):
    """Regional Edge — light blue circle with inner ring."""
    ax.add_patch(plt.Circle((x, y), r,     color=F5_LITE, zorder=z))
    ax.add_patch(plt.Circle((x, y), r,     fill=False, color=F5_BLUE, lw=2, zorder=z+1))
    ax.add_patch(plt.Circle((x, y), r*0.5, color=F5_BLUE, alpha=0.45, zorder=z+1))


def draw_person(ax, x, y, size=0.5, z=12):
    """Stick person with globe underneath."""
    ax.add_patch(plt.Circle((x, y + size*0.90), size*0.25,
                             color="#444444", zorder=z))
    ax.add_patch(plt.Circle((x, y),             size*0.55,
                             color="#DDEEFF", zorder=z))
    ax.add_patch(plt.Circle((x, y),             size*0.55,
                             fill=False, color=F5_BLUE, lw=1.5, zorder=z+1))
    # globe grid lines
    for dy in [-size*0.15, size*0.15]:
        ax.plot([x - size*0.5, x + size*0.5], [y + dy, y + dy],
                color=F5_BLUE, lw=0.8, zorder=z+1)
    ax.plot([x, x], [y - size*0.5, y + size*0.5],
            color=F5_BLUE, lw=0.8, zorder=z+1)


def draw_ce(ax, x, y, size=0.35, z=12):
    """Customer Edge — golden stacked boxes."""
    for i, c in enumerate([GOLD1, GOLD2, GOLD3]):
        ax.add_patch(mpatches.FancyBboxPatch(
            (x - size*0.9 + i*size*0.18, y - size*0.6 + i*size*0.22),
            size*1.8, size*1.2,
            boxstyle="round,pad=0.04",
            facecolor=c, edgecolor="white", lw=1.2, zorder=z+i))


def draw_waap(ax, x, y, size=0.38, z=12):
    """WAAP — green shield."""
    px = [x, x+size, x+size*0.7, x, x-size*0.7, x-size, x]
    py = [y+size*1.35, y+size*0.7, y-size*0.3,
          y-size*1.25, y-size*0.3, y+size*0.7, y+size*1.35]
    ax.fill(px, py,   color=GREEN_WAF, zorder=z)
    ax.plot(px, py,   color="white",   lw=1.5, zorder=z+1)
    ax.text(x, y, "✓", ha="center", va="center", fontsize=14,
            color="white", fontweight="bold", zorder=z+2)


def draw_lb(ax, x, y, size=0.40, z=12):
    """Load Balancer — blue square with fork arrows."""
    ax.add_patch(mpatches.FancyBboxPatch(
        (x-size, y-size), size*2, size*2,
        boxstyle="round,pad=0.05",
        facecolor=LB_BLUE, edgecolor="white", lw=2, zorder=z))
    for dy in [-size*0.35, size*0.35]:
        ax.annotate("", xy=(x+size*0.6, y+dy), xytext=(x, y),
                    arrowprops=dict(arrowstyle="-|>", color="white", lw=1.5),
                    zorder=z+1)
    ax.plot([x-size*0.5, x], [y, y], "w-", lw=2, zorder=z+1)


def draw_k8s(ax, x, y, size=0.38, z=12):
    """App — Kubernetes blue circle."""
    ax.add_patch(plt.Circle((x, y), size, color=K8S_BLUE, zorder=z))
    ax.text(x, y, "K", ha="center", va="center",
            color="white", fontsize=14, fontweight="bold", zorder=z+1)
    ax.text(x, y - size - 0.22, "app", ha="center", va="top",
            fontsize=9, fontweight="bold", zorder=z+1)


def label_box(ax, x, y, txt, w=2.3, h=0.7, z=14):
    ax.add_patch(mpatches.FancyBboxPatch(
        (x-w/2, y-h/2), w, h,
        boxstyle="round,pad=0.05",
        facecolor="white", edgecolor="#666666", lw=1.5, zorder=z))
    ax.text(x, y, txt, ha="center", va="center", fontsize=9,
            fontweight="bold", zorder=z+1, multialignment="center")


def arrow(ax, x1, y1, x2, y2, color, lw=2.8, rad=0.0, label="", z=20):
    ax.annotate("", xy=(x2, y2), xytext=(x1, y1),
                arrowprops=dict(
                    arrowstyle="-|>",
                    color=color, lw=lw,
                    connectionstyle=f"arc3,rad={rad}"),
                zorder=z)
    if label:
        mx = (x1+x2)/2
        my = (y1+y2)/2 + 0.25
        ax.text(mx, my, label, ha="center", va="bottom",
                fontsize=8, color=color, fontweight="bold", zorder=z+1)


# ─────────────────────────────── legend ──────────────────────────────────────

lx, ly = 0.4, H - 0.5
ax.text(lx, ly, "Key:", fontsize=11, fontweight="bold", va="top")

# Icon legend
icon_items = [
    ("Customer Edge", "ce"),
    ("Load Balancer",  "lb"),
    ("WAAP",           "waap"),
    ("Regional Edge",  "re"),
]
for i, (lbl, kind) in enumerate(icon_items):
    iy = ly - 0.85 - i*0.75
    ix = lx + 0.4
    if kind == "re":
        draw_re(ax, ix, iy, r=0.22, z=5)
    elif kind == "lb":
        draw_lb(ax, ix, iy, size=0.28, z=5)
    elif kind == "ce":
        draw_ce(ax, ix, iy, size=0.22, z=5)
    elif kind == "waap":
        draw_waap(ax, ix, iy, size=0.24, z=5)
    ax.text(lx + 0.9, iy, lbl, va="center", fontsize=9)

# Line legend
line_items = [
    (CFG_CLR,  "Config plane"),
    (DATA_CLR, "Client data traffic"),
    (CTRL_CLR, "Control plane"),
]
for i, (col, lbl) in enumerate(line_items):
    iy = ly - 4.0 - i*0.70
    ax.plot([lx+0.1, lx+0.7], [iy, iy], color=col, lw=3)
    ax.text(lx + 0.9, iy, lbl, va="center", fontsize=9)


# ─────────────────────────── Admin (top-left) ────────────────────────────────

admin_x, admin_y = 4.8, 9.2
draw_person(ax, admin_x, admin_y)
label_box(ax, admin_x - 0.4, admin_y - 1.6, "Admin|SecOps|DevOps\n|NetOps", w=2.5)


# ─────────────────────────── End User (bottom-left) ──────────────────────────

user_x, user_y = 4.8, 4.2
draw_person(ax, user_x, user_y)
label_box(ax, user_x - 0.4, user_y - 1.6, "End User", w=1.8)


# ─────────────────────────── F5 Cloud (center) ───────────────────────────────

cx, cy = 11.0, 6.5
cw, ch = 5.8, 4.4
draw_cloud(ax, cx, cy, cw, ch)

ax.text(cx, cy - 0.2,
        "F5 Distributed Cloud\nGlobal Network\n[Private Backbone]",
        ha="center", va="center", fontsize=12,
        color=F5_BLUE, fontweight="bold", zorder=14)

# Regional Edges — 8 nodes arranged on an ellipse inside the cloud
n_re = 8
re_pos = []
for i in range(n_re):
    angle = np.pi/2 + i * (2*np.pi / n_re)
    rx = cx + cw*0.36 * np.cos(angle)
    ry = cy + ch*0.36 * np.sin(angle)
    re_pos.append((rx, ry))
    draw_re(ax, rx, ry, r=0.30, z=15)


# ─────────────────────────── AWS Cloud (right) ───────────────────────────────

aws_cx, aws_cy = 17.2, 6.2
aws_w,  aws_h  = 4.5, 4.8
draw_aws_cloud(ax, aws_cx, aws_cy, aws_w, aws_h)

ax.text(aws_cx - 0.3, aws_cy + aws_h*0.38, "aws",
        ha="center", va="center", fontsize=18,
        fontweight="bold", color=AWS_CLR, zorder=16)

label_box(ax, aws_cx + 1.0, aws_cy + aws_h*0.52, "VIP Advertisement", w=2.0, h=0.5, z=16)

lb_x,   lb_y   = aws_cx + 0.9, aws_cy + aws_h*0.38
ce_x,   ce_y   = aws_cx - 0.6, aws_cy - 0.3
waap_x, waap_y = aws_cx + 0.5, aws_cy + 0.1
app_x,  app_y  = aws_cx + 0.9, aws_cy - 0.8

draw_lb  (ax, lb_x,   lb_y)
draw_ce  (ax, ce_x,   ce_y)
draw_waap(ax, waap_x, waap_y)
draw_k8s (ax, app_x,  app_y)

label_box(ax, aws_cx + 0.3, aws_cy - aws_h*0.47,
          "Client app deployed in\nAWS EKS Cluster", w=2.8, h=0.75, z=16)

# Labels under icons
ax.text(ce_x,   ce_y   - 0.55, "Customer\nEdge (CE)", ha="center", va="top",   fontsize=8, fontweight="bold", zorder=16)
ax.text(waap_x, waap_y - 0.58, "WAAP",                ha="center", va="top",   fontsize=8, fontweight="bold", zorder=16)
ax.text(lb_x,   lb_y   - 0.55, "Load Balancer",       ha="center", va="top",   fontsize=8, fontweight="bold", zorder=16)


# ─────────────────────────── Arrows ──────────────────────────────────────────

# Control plane (light blue): Admin → top RE
re_top   = re_pos[0]   # top
re_top2  = re_pos[7]   # top-left
arrow(ax, admin_x, admin_y + 0.5, re_top[0],  re_top[1],
      CTRL_CLR, label="Control plane", rad=-0.15)
arrow(ax, admin_x, admin_y + 0.4, re_top2[0], re_top2[1],
      CTRL_CLR, rad=-0.05)

# Config plane (dark green): right RE → CE
re_right = re_pos[2]   # right
arrow(ax, re_right[0], re_right[1], ce_x, ce_y + 0.4,
      CFG_CLR, label="Config plane", rad=-0.25)

# Client data traffic (green): End User → bottom arc → CE
arrow(ax, user_x, user_y - 0.3, ce_x, ce_y - 0.3,
      DATA_CLR, label="Client data traffic", rad=-0.35)

# CE → WAAP → LB → app
arrow(ax, ce_x + 0.35, ce_y + 0.2, waap_x - 0.35, waap_y,  DATA_CLR)
arrow(ax, waap_x + 0.4, waap_y + 0.4, lb_x - 0.4,  lb_y,   DATA_CLR)
arrow(ax, lb_x,  lb_y - 0.4,          app_x,        app_y + 0.4, DATA_CLR)

# ─────────────────────────── Save ────────────────────────────────────────────

plt.savefig("img-waf-on-ce-aws.png", dpi=150, bbox_inches="tight",
            facecolor="white", edgecolor="none")
plt.close()
print("✅  img-waf-on-ce-aws.png generated")

from diagrams.aws.network import ELB
from diagrams.aws.security import WAF, Shield
from diagrams.generic.network import Switch

# ── Traffic plane colours ──────────────────────────────────────────────────
CTRL  = {"color": "#29B6F6", "style": "bold", "penwidth": "3"}
DATA  = {"color": "#66BB6A", "style": "bold", "penwidth": "3"}
CFG   = {"color": "#1B5E20", "style": "bold", "penwidth": "3"}
INVIS = {"style": "invis"}


def make_cloud_png(path: str) -> None:
    """Draw a blue cloud PNG for the F5 Distributed Cloud node."""
    fig, ax = plt.subplots(figsize=(5, 3.2))
    fig.patch.set_facecolor("none")
    ax.set_facecolor("none")
    ax.set_xlim(0, 5)
    ax.set_ylim(0, 3.2)
    ax.axis("off")

    blue = "#1565C0"
    # Cloud bumps (circles) + flat bottom (rectangle)
    bumps = [
        (2.5, 1.9, 1.1),
        (1.4, 1.6, 0.80),
        (3.6, 1.6, 0.80),
        (0.7, 1.3, 0.60),
        (4.3, 1.3, 0.60),
        (2.0, 1.3, 0.65),
        (3.0, 1.3, 0.65),
    ]
    for cx, cy, r in bumps:
        ax.add_patch(patches.Circle((cx, cy), r, color=blue, zorder=1))
    # flat base
    ax.add_patch(patches.FancyBboxPatch(
        (0.15, 0.55), 4.7, 0.95,
        boxstyle="round,pad=0.05", color=blue, zorder=0))

    # label inside cloud
    ax.text(2.5, 1.45,
            "F5 Distributed Cloud\nGlobal Network\n[Private Backbone]",
            ha="center", va="center", fontsize=11,
            color="white", fontweight="bold", zorder=2)

    plt.savefig(path, transparent=True, dpi=130, bbox_inches="tight",
                facecolor="none", edgecolor="none")
    plt.close()


CLOUD_PNG = os.path.join(os.path.dirname(__file__), "f5_cloud_node.png")
make_cloud_png(CLOUD_PNG)

# ── Main diagram ───────────────────────────────────────────────────────────
with Diagram(
    "WAF on CE AWS",
    show=False,
    outformat="png",
    filename="img-waf-on-ce-aws",
    direction="LR",
    graph_attr={
        "splines":  "curved",
        "bgcolor":  "white",
        "pad":      "1.5",
        "nodesep":  "0.6",
        "ranksep":  "2.0",
        "compound": "true",
        "fontname": "Helvetica",
        "fontsize": "14",
    },
    node_attr={
        "fontname": "Helvetica",
        "fontsize": "11",
    },
):
    admin    = Users("Admin | SecOps\nDevOps | NetOps")
    end_user = User("End User")

    # F5 cloud rendered as a Custom PNG node
    f5_cloud = Custom(
        "F5 Distributed Cloud\nGlobal Network\n[Private Backbone]",
        CLOUD_PNG,
    )

    # Regional Edges inside an invisible cluster (keeps them grouped together)
    with Cluster(
        "",
        graph_attr={
            "style":    "invis",
            "margin":   "10",
        },
    ):
        re1 = Switch("Regional\nEdge")
        re2 = Switch("Regional\nEdge")
        re3 = Switch("Regional\nEdge")
        re4 = Switch("Regional\nEdge")
        re5 = Switch("Regional\nEdge")
        re6 = Switch("Regional\nEdge")
        # invisible ring to keep RE nodes together
        re1 - Edge(**INVIS) - re2 - Edge(**INVIS) - re3
        re4 - Edge(**INVIS) - re5 - Edge(**INVIS) - re6
        re3 - Edge(**INVIS) - re4

    # Anchor RE cluster to the cloud node so they stay together visually
    f5_cloud - Edge(**INVIS) - re1
    f5_cloud - Edge(**INVIS) - re6

    # AWS side
    with Cluster(
        "AWS",
        graph_attr={
            "style":    "rounded",
            "bgcolor":  "#FFFDE7",
            "color":    "#E65100",
            "penwidth": "3",
            "fontname": "Helvetica-Bold",
            "fontsize": "14",
            "margin":   "30",
        },
    ):
        lb   = ELB("Load Balancer\n[VIP Advertisement]")
        ce   = WAF("Customer Edge (CE)")
        waap = Shield("WAAP")

        with Cluster(
            "EKS Cluster\nClient app deployed in AWS EKS Cluster",
            graph_attr={
                "style":    "rounded",
                "bgcolor":  "#F1F8E9",
                "color":    "#33691E",
                "penwidth": "2",
            },
        ):
            app = EKS("app")

    # ── Control plane (light blue): Admin → F5 cloud / RE ──────────────────
    admin >> Edge(**CTRL, label="Control plane") >> re1
    admin >> Edge(**CTRL) >> re2

    # ── Config plane (dark green): RE → CE ─────────────────────────────────
    re5 >> Edge(**CFG, label="Config plane") >> ce
    re6 >> Edge(**CFG) >> ce

    # ── Client data traffic (green) ─────────────────────────────────────────
    end_user >> Edge(**DATA, label="Client data traffic") >> re3
    re3      >> Edge(**DATA) >> f5_cloud
    f5_cloud >> Edge(**DATA) >> ce
    ce       >> Edge(**DATA) >> waap
    waap     >> Edge(**DATA) >> lb
    lb       >> Edge(**DATA) >> app


with Diagram(
    "WAF on CE AWS",
    show=False,
    outformat="png",
    filename="img-waf-on-ce-aws",
    direction="LR",
    graph_attr={
        "splines":   "curved",
        "bgcolor":   "white",
        "pad":       "1.5",
        "nodesep":   "0.5",
        "ranksep":   "2.0",
        "compound":  "true",       # allows edges to attach to cluster borders
        "fontname":  "Helvetica",
        "fontsize":  "14",
    },
    node_attr={
        "fontname": "Helvetica",
        "fontsize": "11",
    },
):
    # ── Left: human actors ─────────────────────────────────────────────────
    admin    = Users("Admin | SecOps\nDevOps | NetOps")
    end_user = User("End User")

    # ── Centre: F5 Global Network ──────────────────────────────────────────
    with Cluster(
        "F5 Distributed Cloud\nGlobal Network [Private Backbone]",
        graph_attr={
            "style":     "rounded,filled",
            "bgcolor":   "#DDEEFF",
            "color":     "#1565C0",
            "penwidth":  "5",
            "fontcolor": "#1565C0",
            "fontsize":  "15",
            "fontname":  "Helvetica-Bold",
            "margin":    "40",
        },
    ):
        re1 = Switch("Regional\nEdge")
        re2 = Switch("Regional\nEdge")
        re3 = Switch("Regional\nEdge")
        re4 = Switch("Regional\nEdge")
        re5 = Switch("Regional\nEdge")
        re6 = Switch("Regional\nEdge")
        # Invisible ring to keep all RE nodes grouped inside the cluster
        re1 - Edge(**INVIS) - re2
        re2 - Edge(**INVIS) - re3
        re3 - Edge(**INVIS) - re4
        re4 - Edge(**INVIS) - re5
        re5 - Edge(**INVIS) - re6
        re6 - Edge(**INVIS) - re1

    # ── Right: AWS cloud ───────────────────────────────────────────────────
    with Cluster(
        "AWS",
        graph_attr={
            "style":    "rounded",
            "bgcolor":  "#FFFDE7",
            "color":    "#E65100",
            "penwidth": "3",
            "fontname": "Helvetica-Bold",
            "fontsize": "14",
            "margin":   "30",
        },
    ):
        lb   = ELB("Load Balancer\n[VIP Advertisement]")
        ce   = WAF("Customer Edge (CE)")
        waap = Shield("WAAP")

        with Cluster(
            "EKS Cluster\nClient app deployed in AWS EKS Cluster",
            graph_attr={
                "style":    "rounded",
                "bgcolor":  "#F1F8E9",
                "color":    "#33691E",
                "penwidth": "2",
            },
        ):
            app = EKS("app")

    # ── Control plane (light blue): Admin → Regional Edges (top of cloud) ──
    admin >> Edge(**CTRL, label="Control plane") >> re1
    admin >> Edge(**CTRL) >> re2

    # ── Config plane (dark green): Regional Edges → CE ─────────────────────
    re5 >> Edge(**CFG, label="Config plane") >> ce
    re6 >> Edge(**CFG) >> ce

    # ── Client data traffic (green): End User → RE → CE → WAAP → LB → app ─
    end_user >> Edge(**DATA, label="Client data traffic") >> re3
    re3      >> Edge(**DATA) >> ce
    ce       >> Edge(**DATA) >> waap
    waap     >> Edge(**DATA) >> lb
    lb       >> Edge(**DATA) >> app
