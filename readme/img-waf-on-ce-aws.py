from diagrams import Diagram, Cluster, Edge
from diagrams.onprem.client import User, Users
from diagrams.aws.compute import EKS
from diagrams.aws.network import ELB
from diagrams.aws.security import WAF, Shield
from diagrams.generic.network import Switch

# ── Traffic plane colours matching the legend ──────────────────────────────
CTRL = {"color": "#29B6F6", "style": "bold", "penwidth": "3"}  # Control plane  — light blue
DATA = {"color": "#66BB6A", "style": "bold", "penwidth": "3"}  # Client traffic — light green
CFG  = {"color": "#1B5E20", "style": "bold", "penwidth": "3"}  # Config plane   — dark green

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
        "nodesep":  "0.8",
        "ranksep":  "2.0",
        "fontname": "Helvetica",
        "fontsize": "14",
    },
    node_attr={
        "fontname": "Helvetica",
        "fontsize": "12",
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
            "penwidth":  "4",
            "fontcolor": "#1565C0",
            "fontsize":  "16",
            "fontname":  "Helvetica-Bold",
        },
    ):
        re1 = Switch("Regional Edge")
        re2 = Switch("Regional Edge")
        re3 = Switch("Regional Edge")
        re4 = Switch("Regional Edge")
        re5 = Switch("Regional Edge")
        re6 = Switch("Regional Edge")

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
        },
    ):
        # VIP Advertisement — LB is the entry point from the CE into AWS
        lb = ELB("Load Balancer\n[VIP Advertisement]")

        # Customer Edge + WAAP (inline WAF inspection) then the app
        ce   = WAF("Customer Edge (CE)")
        waap = Shield("WAAP")

        with Cluster(
            "EKS Cluster\nClient app deployed in\nAWS EKS Cluster",
            graph_attr={
                "style":    "rounded",
                "bgcolor":  "#F1F8E9",
                "color":    "#33691E",
                "penwidth": "2",
            },
        ):
            app = EKS("app")

    # ── Control plane (light blue): Admin → Regional Edges ─────────────────
    admin >> Edge(**CTRL, label="Control plane") >> re1
    admin >> Edge(**CTRL) >> re2
    admin >> Edge(**CTRL) >> re3

    # ── Config plane (dark green): Regional Edges → CE ─────────────────────
    re4 >> Edge(**CFG, label="Config plane") >> ce
    re5 >> Edge(**CFG) >> ce
    re6 >> Edge(**CFG) >> ce

    # ── Client data traffic (light green): End User → CE → WAAP → LB → app ─
    end_user >> Edge(**DATA, label="Client data traffic") >> ce
    ce       >> Edge(**DATA) >> waap
    waap     >> Edge(**DATA) >> lb
    lb       >> Edge(**DATA) >> app
