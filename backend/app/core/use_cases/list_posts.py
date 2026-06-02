from app.core.entities.community import Post
from app.core.use_cases.interfaces import PostRepository


def list_posts(
    repo: PostRepository,
    page: int = 1,
    page_size: int = 20,
    political_actor_id: int | None = None,
    theme_slug: str | None = None,
) -> tuple[list[Post], int]:
    return repo.list(
        page=page,
        page_size=page_size,
        political_actor_id=political_actor_id,
        theme_slug=theme_slug,
    )
