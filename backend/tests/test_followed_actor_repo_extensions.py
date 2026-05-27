import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.infrastructure.database.models import Base, FollowedActorModel, PoliticalActorModel
from app.infrastructure.database.political_actor_repositories import SqlFollowedActorRepository


@pytest.fixture()
def db() -> Session:
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    _SessionLocal = sessionmaker(bind=engine)
    session = _SessionLocal()
    yield session
    session.close()


def _seed(db: Session):
    actor_a = PoliticalActorModel(
        source="camara", source_id="1", normalized_name="fulano", display_name="Fulano",
        role="federal_deputy", status="active",
    )
    actor_b = PoliticalActorModel(
        source="camara", source_id="2", normalized_name="ciclano", display_name="Ciclano",
        role="federal_deputy", status="active",
    )
    db.add_all([actor_a, actor_b])
    db.flush()
    db.add(FollowedActorModel(anonymous_id="user-1", political_actor_id=actor_a.id))
    db.add(FollowedActorModel(anonymous_id="user-2", political_actor_id=actor_a.id))
    db.add(FollowedActorModel(anonymous_id="user-3", political_actor_id=actor_b.id))
    db.commit()
    return actor_a.id, actor_b.id


def test_list_followed_political_actor_ids(db: Session) -> None:
    actor_a_id, actor_b_id = _seed(db)
    repo = SqlFollowedActorRepository(db)

    ids = repo.list_followed_political_actor_ids()

    assert set(ids) == {actor_a_id, actor_b_id}


def test_list_anonymous_ids_by_political_actor(db: Session) -> None:
    actor_a_id, _ = _seed(db)
    repo = SqlFollowedActorRepository(db)

    anon_ids = repo.list_anonymous_ids_by_political_actor(actor_a_id)

    assert set(anon_ids) == {"user-1", "user-2"}


def test_list_anonymous_ids_returns_empty_for_unknown_actor(db: Session) -> None:
    _seed(db)
    repo = SqlFollowedActorRepository(db)

    assert repo.list_anonymous_ids_by_political_actor(99999) == []
