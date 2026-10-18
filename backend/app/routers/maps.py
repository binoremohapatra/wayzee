from fastapi import APIRouter, HTTPException, Query, Depends
from sqlmodel import Session
from typing import Optional
import qrcode
from io import BytesIO
from fastapi.responses import Response

from app.database import get_session
from app.models import MapCreate, MapRead, MapList
from app.services.map_service import (
    create_map,
    get_maps,
    get_map_by_id,
    update_map,
    delete_map,
    MapValidationError,
)
from app.config import settings

router = APIRouter(prefix="/v1/maps", tags=["maps"])


@router.post("", response_model=MapRead, status_code=201)
def create_map_endpoint(
    map_data: MapCreate,
    session: Session = Depends(get_session),
):
    """Upload a new map."""
    try:
        return create_map(session, map_data)
    except MapValidationError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("", response_model=list[MapList])
def list_maps(
    building: Optional[str] = Query(None, description="Filter by building name"),
    name: Optional[str] = Query(None, description="Filter by map name"),
    skip: int = Query(0, ge=0, description="Number of maps to skip"),
    limit: int = Query(100, ge=1, le=1000, description="Number of maps to return"),
    session: Session = Depends(get_session),
):
    """List maps with optional filtering and pagination."""
    return get_maps(session, building=building, name=name, skip=skip, limit=limit)


@router.get("/{map_id}", response_model=MapRead)
def get_map(
    map_id: int,
    session: Session = Depends(get_session),
):
    """Get full map JSON including nodes and edges."""
    map_data = get_map_by_id(session, map_id)
    if not map_data:
        raise HTTPException(status_code=404, detail="Map not found")
    return map_data


@router.get("/{map_id}/qr")
def get_map_qr(
    map_id: int,
    session: Session = Depends(get_session),
):
    """Get QR code of map payload or download link."""
    map_data = get_map_by_id(session, map_id)
    if not map_data:
        raise HTTPException(status_code=404, detail="Map not found")

    # Try to encode the full map data
    import json
    payload = json.dumps(map_data.model_dump(mode="json"))

    if len(payload.encode()) <= settings.max_qr_size_bytes:
        # Small enough to encode directly
        qr = qrcode.QRCode(version=1, box_size=10, border=4)
        qr.add_data(payload)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")

        buffer = BytesIO()
        img.save(buffer, format="PNG")
        buffer.seek(0)

        return Response(content=buffer.getvalue(), media_type="image/png")
    else:
        # Too large, return download link QR
        # For demo, just return the endpoint path
        download_url = f"/v1/maps/{map_id}"
        qr = qrcode.QRCode(version=1, box_size=10, border=4)
        qr.add_data(download_url)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")

        buffer = BytesIO()
        img.save(buffer, format="PNG")
        buffer.seek(0)

        return Response(content=buffer.getvalue(), media_type="image/png")


@router.put("/{map_id}", response_model=MapRead)
def update_map_endpoint(
    map_id: int,
    map_data: MapCreate,
    session: Session = Depends(get_session),
):
    """Update a map (owner only)."""
    result = update_map(session, map_id, map_data, map_data.owner_key)
    if not result:
        raise HTTPException(status_code=403, detail="Invalid owner key or map not found")
    return result


@router.delete("/{map_id}", status_code=204)
def delete_map_endpoint(
    map_id: int,
    owner_key: str = Query(..., description="Owner API key"),
    session: Session = Depends(get_session),
):
    """Delete a map (owner only)."""
    success = delete_map(session, map_id, owner_key)
    if not success:
        raise HTTPException(status_code=403, detail="Invalid owner key or map not found")
