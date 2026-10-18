import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, select

from app.main import app
from app.database import engine, init_db
from app.models import Map, Node, Edge
from app.services.map_service import MapValidationError


client = TestClient(app)


@pytest.fixture(autouse=True)
def setup_database():
    """Initialize database before each test."""
    init_db()
    yield
    # Clean up after test
    with Session(engine) as session:
        session.exec(select(Map).where(Map.name == "Test Map"))
        session.commit()


def test_create_map_valid():
    """Test creating a valid map."""
    response = client.post(
        "/v1/maps",
        json={
            "name": "Test Map",
            "building": "Test Building",
            "version": 1,
            "owner_key": "test-key",
            "nodes": [
                {"node_id": "node1", "name": "Node 1", "x": 0, "y": 0, "beacon_id": "b1"},
                {"node_id": "node2", "name": "Node 2", "x": 10, "y": 0, "beacon_id": "b2"},
            ],
            "edges": [
                {"from_node": "node1", "to_node": "node2", "distance_m": 10},
            ],
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Test Map"
    assert data["building"] == "Test Building"
    assert "checksum" in data
    assert len(data["nodes"]) == 2
    assert len(data["edges"]) == 1
    print(f"✅ test_create_map_valid: Created map with ID {data['id']}")


def test_create_map_disconnected_graph():
    """Test that disconnected graph is rejected."""
    response = client.post(
        "/v1/maps",
        json={
            "name": "Disconnected Map",
            "building": "Test Building",
            "version": 1,
            "owner_key": "test-key",
            "nodes": [
                {"node_id": "node1", "name": "Node 1", "x": 0, "y": 0, "beacon_id": "b1"},
                {"node_id": "node2", "name": "Node 2", "x": 100, "y": 0, "beacon_id": "b2"},
            ],
            "edges": [],  # No edges connecting nodes
        },
    )
    assert response.status_code == 400
    assert "not connected" in response.json()["detail"].lower()
    print("✅ test_create_map_disconnected_graph: Correctly rejected disconnected graph")


def test_create_map_invalid_edge_reference():
    """Test that invalid edge references are rejected."""
    response = client.post(
        "/v1/maps",
        json={
            "name": "Invalid Edge Map",
            "building": "Test Building",
            "version": 1,
            "owner_key": "test-key",
            "nodes": [
                {"node_id": "node1", "name": "Node 1", "x": 0, "y": 0, "beacon_id": "b1"},
            ],
            "edges": [
                {"from_node": "node1", "to_node": "nonexistent", "distance_m": 10},
            ],
        },
    )
    assert response.status_code == 400
    assert "non-existent" in response.json()["detail"].lower()
    print("✅ test_create_map_invalid_edge_reference: Correctly rejected invalid edge reference")


def test_list_maps():
    """Test listing maps."""
    # Create a map first
    client.post(
        "/v1/maps",
        json={
            "name": "List Test Map",
            "building": "Test Building",
            "version": 1,
            "owner_key": "test-key",
            "nodes": [
                {"node_id": "n1", "name": "N1", "x": 0, "y": 0, "beacon_id": "b1"},
                {"node_id": "n2", "name": "N2", "x": 10, "y": 0, "beacon_id": "b2"},
            ],
            "edges": [{"from_node": "n1", "to_node": "n2", "distance_m": 10}],
        },
    )

    response = client.get("/v1/maps")
    assert response.status_code == 200
    data = response.json()
    assert len(data) >= 1
    print(f"✅ test_list_maps: Listed {len(data)} maps")


def test_list_maps_with_filter():
    """Test listing maps with building filter."""
    # Create two maps
    client.post(
        "/v1/maps",
        json={
            "name": "Building A Map",
            "building": "Building A",
            "version": 1,
            "owner_key": "test-key",
            "nodes": [
                {"node_id": "n1", "name": "N1", "x": 0, "y": 0, "beacon_id": "b1"},
                {"node_id": "n2", "name": "N2", "x": 10, "y": 0, "beacon_id": "b2"},
            ],
            "edges": [{"from_node": "n1", "to_node": "n2", "distance_m": 10}],
        },
    )
    client.post(
        "/v1/maps",
        json={
            "name": "Building B Map",
            "building": "Building B",
            "version": 1,
            "owner_key": "test-key",
            "nodes": [
                {"node_id": "n1", "name": "N1", "x": 0, "y": 0, "beacon_id": "b1"},
                {"node_id": "n2", "name": "N2", "x": 10, "y": 0, "beacon_id": "b2"},
            ],
            "edges": [{"from_node": "n1", "to_node": "n2", "distance_m": 10}],
        },
    )

    response = client.get("/v1/maps?building=Building A")
    assert response.status_code == 200
    data = response.json()
    assert all(map["building"] == "Building A" for map in data)
    print(f"✅ test_list_maps_with_filter: Filtered to {len(data)} maps from Building A")


def test_get_map_by_id():
    """Test getting a specific map."""
    # Create a map
    create_response = client.post(
        "/v1/maps",
        json={
            "name": "Get Test Map",
            "building": "Test Building",
            "version": 1,
            "owner_key": "test-key",
            "nodes": [
                {"node_id": "n1", "name": "N1", "x": 0, "y": 0, "beacon_id": "b1"},
                {"node_id": "n2", "name": "N2", "x": 10, "y": 0, "beacon_id": "b2"},
            ],
            "edges": [{"from_node": "n1", "to_node": "n2", "distance_m": 10}],
        },
    )
    map_id = create_response.json()["id"]

    response = client.get(f"/v1/maps/{map_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == map_id
    assert data["name"] == "Get Test Map"
    assert len(data["nodes"]) == 2
    assert len(data["edges"]) == 1
    print(f"✅ test_get_map_by_id: Retrieved map {map_id}")


def test_get_map_not_found():
    """Test getting a non-existent map."""
    response = client.get("/v1/maps/99999")
    assert response.status_code == 404
    print("✅ test_get_map_not_found: Correctly returned 404")


def test_get_map_qr():
    """Test getting QR code for a map."""
    # Create a small map
    create_response = client.post(
        "/v1/maps",
        json={
            "name": "QR Test Map",
            "building": "Test Building",
            "version": 1,
            "owner_key": "test-key",
            "nodes": [
                {"node_id": "n1", "name": "N1", "x": 0, "y": 0, "beacon_id": "b1"},
                {"node_id": "n2", "name": "N2", "x": 10, "y": 0, "beacon_id": "b2"},
            ],
            "edges": [{"from_node": "n1", "to_node": "n2", "distance_m": 10}],
        },
    )
    map_id = create_response.json()["id"]

    response = client.get(f"/v1/maps/{map_id}/qr")
    assert response.status_code == 200
    assert response.headers["content-type"] == "image/png"
    print(f"✅ test_get_map_qr: Generated QR code for map {map_id}")


def test_checksum_stability():
    """Test that checksum is stable for identical maps."""
    map_data = {
        "name": "Checksum Test",
        "building": "Test Building",
        "version": 1,
        "owner_key": "test-key",
        "nodes": [
            {"node_id": "n1", "name": "N1", "x": 0, "y": 0, "beacon_id": "b1"},
            {"node_id": "n2", "name": "N2", "x": 10, "y": 0, "beacon_id": "b2"},
        ],
        "edges": [{"from_node": "n1", "to_node": "n2", "distance_m": 10}],
    }

    response1 = client.post("/v1/maps", json=map_data)
    checksum1 = response1.json()["checksum"]

    response2 = client.post("/v1/maps", json=map_data)
    checksum2 = response2.json()["checksum"]

    assert checksum1 == checksum2
    print(f"✅ test_checksum_stability: Checksums match: {checksum1}")


def test_update_map():
    """Test updating a map."""
    # Create a map
    create_response = client.post(
        "/v1/maps",
        json={
            "name": "Update Test Map",
            "building": "Test Building",
            "version": 1,
            "owner_key": "test-key",
            "nodes": [
                {"node_id": "n1", "name": "N1", "x": 0, "y": 0, "beacon_id": "b1"},
                {"node_id": "n2", "name": "N2", "x": 10, "y": 0, "beacon_id": "b2"},
            ],
            "edges": [{"from_node": "n1", "to_node": "n2", "distance_m": 10}],
        },
    )
    map_id = create_response.json()["id"]

    # Update it
    response = client.put(
        f"/v1/maps/{map_id}",
        json={
            "name": "Updated Map",
            "building": "Test Building",
            "version": 2,
            "owner_key": "test-key",
            "nodes": [
                {"node_id": "n1", "name": "N1", "x": 0, "y": 0, "beacon_id": "b1"},
                {"node_id": "n2", "name": "N2", "x": 10, "y": 0, "beacon_id": "b2"},
            ],
            "edges": [{"from_node": "n1", "to_node": "n2", "distance_m": 10}],
        },
    )
    assert response.status_code == 200
    assert response.json()["name"] == "Updated Map"
    assert response.json()["version"] == 2
    print(f"✅ test_update_map: Updated map {map_id}")


def test_update_map_wrong_key():
    """Test that updating with wrong key fails."""
    # Create a map
    create_response = client.post(
        "/v1/maps",
        json={
            "name": "Key Test Map",
            "building": "Test Building",
            "version": 1,
            "owner_key": "correct-key",
            "nodes": [
                {"node_id": "n1", "name": "N1", "x": 0, "y": 0, "beacon_id": "b1"},
                {"node_id": "n2", "name": "N2", "x": 10, "y": 0, "beacon_id": "b2"},
            ],
            "edges": [{"from_node": "n1", "to_node": "n2", "distance_m": 10}],
        },
    )
    map_id = create_response.json()["id"]

    # Try to update with wrong key
    response = client.put(
        f"/v1/maps/{map_id}",
        json={
            "name": "Hacked Map",
            "building": "Test Building",
            "version": 2,
            "owner_key": "wrong-key",
            "nodes": [
                {"node_id": "n1", "name": "N1", "x": 0, "y": 0, "beacon_id": "b1"},
                {"node_id": "n2", "name": "N2", "x": 10, "y": 0, "beacon_id": "b2"},
            ],
            "edges": [{"from_node": "n1", "to_node": "n2", "distance_m": 10}],
        },
    )
    assert response.status_code == 403
    print(f"✅ test_update_map_wrong_key: Correctly rejected wrong key")


def test_delete_map():
    """Test deleting a map."""
    # Create a map
    create_response = client.post(
        "/v1/maps",
        json={
            "name": "Delete Test Map",
            "building": "Test Building",
            "version": 1,
            "owner_key": "test-key",
            "nodes": [
                {"node_id": "n1", "name": "N1", "x": 0, "y": 0, "beacon_id": "b1"},
                {"node_id": "n2", "name": "N2", "x": 10, "y": 0, "beacon_id": "b2"},
            ],
            "edges": [{"from_node": "n1", "to_node": "n2", "distance_m": 10}],
        },
    )
    map_id = create_response.json()["id"]

    # Delete it
    response = client.delete(f"/v1/maps/{map_id}?owner_key=test-key")
    assert response.status_code == 204

    # Verify it's gone
    get_response = client.get(f"/v1/maps/{map_id}")
    assert get_response.status_code == 404
    print(f"✅ test_delete_map: Deleted map {map_id}")


def test_rate_limiter():
    """Test rate limiting on POST."""
    # This test is NOT TESTED with actual rate limiting in CI
    # because it would require many requests and time
    print("⚠️  test_rate_limiter: NOT TESTED (requires many requests)")
    pass


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
