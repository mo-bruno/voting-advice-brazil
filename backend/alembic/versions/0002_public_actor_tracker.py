"""public_actor_tracker

Revision ID: 0002_public_actor_tracker
Revises: 0001_initial_schema
Create Date: 2026-05-06 16:45:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0002_public_actor_tracker"
down_revision: Union[str, Sequence[str], None] = "0001_initial_schema"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "political_actors",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("source", sa.String(length=32), nullable=False),
        sa.Column("source_id", sa.String(length=64), nullable=False),
        sa.Column("normalized_name", sa.String(length=256), nullable=False),
        sa.Column("display_name", sa.String(length=256), nullable=False),
        sa.Column("party", sa.String(length=32), nullable=True),
        sa.Column("state", sa.String(length=2), nullable=True),
        sa.Column("role", sa.String(length=64), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("photo_url", sa.String(length=1024), nullable=True),
        sa.Column("source_url", sa.String(length=1024), nullable=True),
        sa.Column("last_indexed_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "source",
            "source_id",
            name="uq_political_actors_source_id",
        ),
    )
    with op.batch_alter_table("political_actors", schema=None) as batch_op:
        batch_op.create_index(
            "ix_political_actors_normalized_name",
            ["normalized_name"],
            unique=False,
        )
        batch_op.create_index(
            "ix_political_actors_role_state_party",
            ["role", "state", "party"],
            unique=False,
        )

    op.create_table(
        "source_sync_cursors",
        sa.Column("source", sa.String(length=32), nullable=False),
        sa.Column("cursor_name", sa.String(length=64), nullable=False),
        sa.Column("cursor_value", sa.String(length=512), nullable=True),
        sa.Column("refreshed_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("source", "cursor_name"),
    )

    op.create_table(
        "source_sync_runs",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("source", sa.String(length=32), nullable=False),
        sa.Column("operation", sa.String(length=64), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("message", sa.Text(), nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("source_sync_runs", schema=None) as batch_op:
        batch_op.create_index(
            "ix_source_sync_runs_source_operation",
            ["source", "operation"],
            unique=False,
        )

    op.create_table(
        "followed_actors",
        sa.Column("anonymous_id", sa.String(length=64), nullable=False),
        sa.Column("political_actor_id", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["political_actor_id"], ["political_actors.id"]),
        sa.PrimaryKeyConstraint("anonymous_id"),
    )
    with op.batch_alter_table("followed_actors", schema=None) as batch_op:
        batch_op.create_index(
            "ix_followed_actors_actor",
            ["political_actor_id"],
            unique=False,
        )

    op.create_table(
        "official_evidence",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("political_actor_id", sa.Integer(), nullable=False),
        sa.Column("source", sa.String(length=32), nullable=False),
        sa.Column("source_id", sa.String(length=128), nullable=False),
        sa.Column("evidence_type", sa.String(length=32), nullable=False),
        sa.Column("title", sa.String(length=512), nullable=False),
        sa.Column("summary", sa.Text(), nullable=False),
        sa.Column("evidence_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("source_url", sa.String(length=1024), nullable=True),
        sa.Column("normalized_payload", sa.JSON(), nullable=True),
        sa.Column("fetched_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["political_actor_id"], ["political_actors.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "political_actor_id",
            "source",
            "source_id",
            "evidence_type",
            name="uq_evidence_actor_source_type",
        ),
    )
    with op.batch_alter_table("official_evidence", schema=None) as batch_op:
        batch_op.create_index(
            "ix_evidence_actor_type_date",
            ["political_actor_id", "evidence_type", "evidence_date"],
            unique=False,
        )
        batch_op.create_index(
            "ix_evidence_expires_at",
            ["expires_at"],
            unique=False,
        )


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("official_evidence", schema=None) as batch_op:
        batch_op.drop_index("ix_evidence_expires_at")
        batch_op.drop_index("ix_evidence_actor_type_date")

    op.drop_table("official_evidence")

    with op.batch_alter_table("followed_actors", schema=None) as batch_op:
        batch_op.drop_index("ix_followed_actors_actor")

    op.drop_table("followed_actors")

    with op.batch_alter_table("source_sync_runs", schema=None) as batch_op:
        batch_op.drop_index("ix_source_sync_runs_source_operation")

    op.drop_table("source_sync_runs")
    op.drop_table("source_sync_cursors")

    with op.batch_alter_table("political_actors", schema=None) as batch_op:
        batch_op.drop_index("ix_political_actors_role_state_party")
        batch_op.drop_index("ix_political_actors_normalized_name")

    op.drop_table("political_actors")
