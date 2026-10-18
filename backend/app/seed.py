from sqlmodel import Session
from app.database import engine, init_db
from app.models import MapCreate, NodeBase, EdgeBase
from app.services.map_service import create_map


def seed_sample_map():
    """Insert sample map matching the app's hardcoded graph."""
    init_db()

    with Session(engine) as session:
        # Create sample map: Entrance, Corridor, Lift, Room 101, Washroom, Exit
        sample_map = MapCreate(
            name="Sample Office Building",
            building="Demo Building",
            version=1,
            owner_key="demo-key-123",
            nodes=[
                NodeBase(node_id="entrance", name="Main Entrance", x=0, y=0, beacon_id="beacon-001"),
                NodeBase(node_id="corridor", name="Main Corridor", x=10, y=0, beacon_id="beacon-002"),
                NodeBase(node_id="lift", name="Elevator", x=20, y=0, beacon_id="beacon-003"),
                NodeBase(node_id="room101", name="Room 101", x=10, y=10, beacon_id="beacon-004"),
                NodeBase(node_id="washroom", name="Washroom", x=20, y=10, beacon_id="beacon-005"),
                NodeBase(node_id="exit", name="Emergency Exit", x=30, y=0, beacon_id="beacon-006"),
            ],
            edges=[
                EdgeBase(from_node="entrance", to_node="corridor", distance_m=10),
                EdgeBase(from_node="corridor", to_node="lift", distance_m=10),
                EdgeBase(from_node="corridor", to_node="room101", distance_m=10),
                EdgeBase(from_node="lift", to_node="washroom", distance_m=10),
                EdgeBase(from_node="room101", to_node="washroom", distance_m=10),
                EdgeBase(from_node="lift", to_node="exit", distance_m=10),
            ],
        )

        try:
            created = create_map(session, sample_map)
            print(f"[OK] Sample map created with ID: {created.id}")
            print(f"   Name: {created.name}")
            print(f"   Building: {created.building}")
            print(f"   Checksum: {created.checksum}")
            print(f"   Nodes: {len(created.nodes)}")
            print(f"   Edges: {len(created.edges)}")
        except Exception as e:
            print(f"[ERROR] Error creating sample map: {e}")


if __name__ == "__main__":
    seed_sample_map()
