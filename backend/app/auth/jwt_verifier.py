import jwt
from fastapi import Header, HTTPException, status
from jwt import PyJWKClient

from app.config import settings


_jwks_clients: dict[str, PyJWKClient] = {}


def _decode_token(token: str) -> dict:
    algorithm = jwt.get_unverified_header(token).get("alg")
    if algorithm == "HS256":
        if settings.is_production:
            raise jwt.InvalidAlgorithmError("HS256 not allowed in production")
        if not settings.supabase_jwt_secret:
            raise jwt.InvalidAlgorithmError("JWT secret not configured for HS256")
        return jwt.decode(
            token,
            settings.supabase_jwt_secret,
            algorithms=["HS256"],
            audience="authenticated",
        )
    if algorithm not in {"ES256", "RS256"}:
        raise jwt.InvalidAlgorithmError("Unsupported signing algorithm")

    issuer = f"{settings.supabase_url.rstrip('/')}/auth/v1"
    jwks_url = f"{issuer}/.well-known/jwks.json"
    jwks_client = _jwks_clients.setdefault(jwks_url, PyJWKClient(jwks_url))
    signing_key = jwks_client.get_signing_key_from_jwt(token).key
    return jwt.decode(
        token,
        signing_key,
        algorithms=[algorithm],
        audience="authenticated",
        issuer=issuer,
    )


async def verify_token(authorization: str = Header(...)) -> dict:
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header format",
        )
    token = authorization.removeprefix("Bearer ")
    try:
        return _decode_token(token)
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )


async def get_current_user_id(authorization: str = Header(...)) -> str:
    payload = await verify_token(authorization)
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token: missing subject claim",
        )
    return user_id
