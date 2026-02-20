from pydantic import BaseModel


class SwipeRequest(BaseModel):
    """Request model for swipe endpoint."""
    user_id: str
    movie_index: int
    action: str  # LIKED, WATCHED, WATCH_LATER, DISLIKE