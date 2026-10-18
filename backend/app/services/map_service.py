import hashlib
import json
from datetime import datetime, timezone
from typing import List, Optional
from collections import defaultdict, deque
from sqlmodel import Session, select
from app.models import Map, MapCreate, MapRead, MapList, Node, Edge, NodeBase, EdgeBase


class MapValidationError(Exception):
    pass


def compute_checksum(map_data: dict) -> str:
    """Compute SHA256 checksum of map data."""
    data_str = json.dumps(map_data, sort_keys=True)
    return hashlib.sha256(data_str.encode()).hexdigest()


def validate_graph(nodes: List[NodeBase], edges: List[EdgeBase]) -> None:
    """Validate that edges reference existing nodes and graph is connected."""
    if not nodes:
        raise MapValidationError("Map must have at least one node")

    node_ids = {node.node_id for node in nodes}

    # Check that all edge references exist
    for edge in edges:
        if edge.from_node not in node_ids:
            raise MapValidationError(f"Edge references non-existent node: {edge.from_node}")
        if edge.to_node not in node_ids:
            raise MapValidationError(f"Edge references non-existent node: {edge.to_node}")

    # Check graph connectivity using BFS
    if nodes:
        adjacency = defaultdict(list)
        for edge in edges:
            adjacency[edge.from_node].append(edge.to_node)
            adjacency[edge.to_node].append(edge.from_node)

        visited = set()
        queue = deque([nodes[0].node_id])

        while queue:
            node_id = queue.popleft()
            if node_id not in visited:
                visited.add(node_id)
                for neighbor in adjacency[node_id]:
                    if neighbor not in visited:
                        queue.append(neighbor)

        if len(visited) != len(node_ids):
            raise MapValidationError("Graph is not connected - some nodes are unreachable")


def create_map(session: Session, map_data: MapCreate) -> MapRead:
    """Create a new map with validation."""
    # Validate graph
    validate_graph(map_data.nodes, map_data.edges)

    # Hash owner key
    from passlib.context import CryptContext
    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
    owner_key_hash = pwd_context.hash(map_data.owner_key)

    # Compute checksum
    map_dict = map_data.model_dump(exclude={"owner_key"})
    checksum = compute_checksum(map_dict)

    # Create map
    db_map = Map(
        name=map_data.name,
        building=map_data.building,
        version=map_data.version,
        owner_key_hash=owner_key_hash,
        checksum=checksum,
    )
    session.add(db_map)
    session.commit()
    session.refresh(db_map)

    # Create nodes
    for node_data in map_data.nodes:
        node = Node(
            node_id=node_data.node_id,
            name=node_data.name,
            x=node_data.x,
            y=node_data.y,
            beacon_id=node_data.beacon_id,
            map_id=db_map.id,
        )
        session.add(node)
    session.commit()

    # Create edges
    for edge_data in map_data.edges:
        edge = Edge(
            from_node=edge_data.from_node,
            to_node=edge_data.to_node,
            distance_m=edge_data.distance_m,
            map_id=db_map.id,
        )
        session.add(edge)
    session.commit()

    session.refresh(db_map)
    return MapRead(
        id=db_map.id,
        name=db_map.name,
        building=db_map.building,
        version=db_map.version,
        checksum=db_map.checksum,
        created_at=db_map.created_at,
        updated_at=db_map.updated_at,
        nodes=[NodeBase(**node.model_dump(exclude={"id", "map_id"})) for node in db_map.nodes],
        edges=[EdgeBase(**edge.model_dump(exclude={"id", "map_id"})) for edge in db_map.edges],
    )


def get_maps(
    session: Session,
    building: Optional[str] = None,
    name: Optional[str] = None,
    skip: int = 0,
    limit: int = 100,
) -> List[MapList]:
    """List maps with optional filtering."""
    query = select(Map)

    if building:
        query = query.where(Map.building.ilike(f"%{building}%"))
    if name:
        query = query.where(Map.name.ilike(f"%{name}%"))

    query = query.offset(skip).limit(limit)
    maps = session.exec(query).all()

    return [
        MapList(
            id=map.id,
            name=map.name,
            building=map.building,
            version=map.version,
            checksum=map.checksum,
            created_at=map.created_at,
        )
        for map in maps
    ]


def get_map_by_id(session: Session, map_id: int) -> Optional[MapRead]:
    """Get full map by ID."""
    db_map = session.get(Map, map_id)
    if not db_map:
        return None

    return MapRead(
        id=db_map.id,
        name=db_map.name,
        building=db_map.building,
        version=db_map.version,
        checksum=db_map.checksum,
        created_at=db_map.created_at,
        updated_at=db_map.updated_at,
        nodes=[NodeBase(**node.model_dump(exclude={"id", "map_id"})) for node in db_map.nodes],
        edges=[EdgeBase(**edge.model_dump(exclude={"id", "map_id"})) for edge in db_map.edges],
    )


def verify_owner(session: Session, map_id: int, owner_key: str) -> bool:
    """Verify owner key for a map."""
    db_map = session.get(Map, map_id)
    if not db_map:
        return False

    from passlib.context import CryptContext
    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
    return pwd_context.verify(owner_key, db_map.owner_key_hash)


def update_map(session: Session, map_id: int, map_data: MapCreate, owner_key: str) -> Optional[MapRead]:
    """Update a map (owner only)."""
    if not verify_owner(session, map_id, owner_key):
        return None

    # Validate graph
    validate_graph(map_data.nodes, map_data.edges)

    db_map = session.get(Map, map_id)
    if not db_map:
        return None

    # Delete old nodes and edges
    session.exec(select(Node).where(Node.map_id == map_id))
    session.exec(select(Edge).where(Edge.map_id == map_id))

    # Update map
    db_map.name = map_data.name
    db_map.building = map_data.building
    db_map.version = map_data.version
    map_dict = map_data.model_dump(exclude={"owner_key"})
    db_map.checksum = compute_checksum(map_dict)
    db_map.updated_at = datetime.now(timezone.utc)

    # Create new nodes
    for node_data in map_data.nodes:
        node = Node(
            node_id=node_data.node_id,
            name=node_data.name,
            x=node_data.x,
            y=node_data.y,
            beacon_id=node_data.beacon_id,
            map_id=db_map.id,
        )
        session.add(node)

    # Create new edges
    for edge_data in map_data.edges:
        edge = Edge(
            from_node=edge_data.from_node,
            to_node=edge_data.to_node,
            distance_m=edge_data.distance_m,
            map_id=db_map.id,
        )
        session.add(edge)

    session.commit()
    session.refresh(db_map)

    return get_map_by_id(session, map_id)


def delete_map(session: Session, map_id: int, owner_key: str) -> bool:
    """Delete a map (owner only)."""
    if not verify_owner(session, map_id, owner_key):
        return False

    db_map = session.get(Map, map_id)
    if not db_map:
        return False

    # Delete nodes and edges
    session.exec(select(Node).where(Node.map_id == map_id))
    session.exec(select(Edge).where(Edge.map_id == map_id))

    # Delete map
    session.delete(db_map)
    session.commit()

    return True
