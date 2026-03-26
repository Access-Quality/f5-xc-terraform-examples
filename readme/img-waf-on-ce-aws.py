from diagrams import Diagram, Cluster, Edge
from diagrams.onprem.client import User, Users
from diagrams.aws.compute import EKS
from diagrams.aws.network import ELB
from diagrams.aws.security import WAF
from diagrams.generic.network import Switch

# Edge styles matching the legend
CTRL = {"color": "#4FC3F7", "style": "bold"}   # Control plane   — light blue
DATA = {"color": "#66BB6A", "style": "bold"}   # Client traffic  — green
CFG  = {"color": "#1B5E20", "style": "bold"}   # Config plane    — dark green

graph_attrs = {
    "splines": "curved",
    "bgcolor": "white",
    "pad": "0.75",
    "fontsize": "13",
}

with Diagram(
    "WAF on CE AWS",
    show=False,
    outformat="png",
    filename="img-waf-on-ce-aws",
    direction="LR",
    graph_attr=graph_attrs,
):
    admin    = Users("Admin | SecOps\nDevOps | NetOps")
    end_user = User("End User")

    with Cluster(
        "F5 Distributed Cloud\nGlobal Network [Private Backbone]",
        graph_attr={
            "style": "rounded,filled",
            "bgcolor": "#E3F2FD",
            "color": "#1565C0",
            "penwidth": "2",
        },
    ):
        re = [Switch("Regional Edge") for _ in range(4)]

    with Cluster(
        "AWS Cloud",
        graph_attr={
            "style": "rounded",
            "bgcolor": "#FFF8E1",
            "color": "#E65100",
            "penwidth": "2",
        },
    ):
        lb = ELB("Load Balancer\n(VIP Advertisement)")

        with Cluster("EKS Cluster"):
            ce  = WAF("Customer Edge\n+ WAAP")
            app = EKS("app")

    # Control plane (light blue): Admin → Regional Edge
    admin >> Edge(**CTRL, label="Control plane") >> re[0]

    # Config plane (dark green): Regional Edge → Customer Edge
    re[0] >> Edge(**CFG, label="Config plane") >> ce

    # Client data traffic (green): End User → LB → CE → App
    end_user >> Edge(**DATA, label="Client data traffic") >> lb
    lb       >> Edge(**DATA) >> ce
    ce       >> Edge(**DATA) >> app
