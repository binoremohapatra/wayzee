from datetime import datetime, timezone
from typing import List, Optional
from sqlmodel import Field, SQLModel, Relationship


class NodeBase(SQLModel):
    node_id: str
    name: str
    x: float
    y: float
    beacon_id: Optional[str] = None


class Node(NodeBase, table=True):
    __tablename__ = "node"
    id: Optional[int] = Field(default=None, primary_key=True)
    node_id: str = Field(index=True)
    name: str
    x: float
    y: float
    beacon_id: Optional[str] = None
    map_id: Optional[int] = Field(default=None, foreign_key="map.id")
    map: Optional["Map"] = Relationship(back_populates="nodes")


class EdgeBase(SQLModel):
    from_node: str
    to_node: str
    distance_m: float


class Edge(EdgeBase, table=True):
    __tablename__ = "edge"
    id: Optional[int] = Field(default=None, primary_key=True)
    from_node: str
    to_node: str
    distance_m: float
    map_id: Optional[int] = Field(default=None, foreign_key="map.id")
    map: Optional["Map"] = Relationship(back_populates="edges")


class MapBase(SQLModel):
    name: str
    building: str
    version: int = 1


class Map(MapBase, table=True):
    __tablename__ = "map"
    id: Optional[int] = Field(default=None, primary_key=True)
    owner_key_hash: str = Field(index=True)
    checksum: str = Field(index=True)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    nodes: List[Node] = Relationship(back_populates="map")
    edges: List[Edge] = Relationship(back_populates="map")


class MapCreate(MapBase):
    nodes: List[NodeBase]
    edges: List[EdgeBase]
    owner_key: str  # Will be hashed before storage


class MapRead(MapBase):
    id: int
    checksum: str
    created_at: datetime
    updated_at: datetime
    nodes: List[NodeBase]
    edges: List[EdgeBase]


class MapList(SQLModel):
    id: int
    name: str
    building: str
    version: int
    checksum: str
    created_at: datetime


class ApiKey(SQLModel, table=True):
    __tablename__ = "apikey"
    id: Optional[int] = Field(default=None, primary_key=True)
    key_hash: str = Field(index=True, unique=True)
    label: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
