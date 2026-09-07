"""community_integrity

Revision ID: 0006_community_integrity
Revises: 0005_community
Create Date: 2026-09-06 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "0006_community_integrity"
down_revision: Union[str, Sequence[str], None] = "0005_community"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "posts",
        sa.Column("removed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "posts",
        sa.Column("removed_by", sa.String(length=16), nullable=True),
    )
    # Serve a contagem do limite de publicacao, que filtra por autor e data.
    op.create_index(
        "ix_posts_author_created", "posts", ["anonymous_id", "created_at"]
    )

    op.create_table(
        "post_reports",
        sa.Column("post_id", sa.String(length=36), nullable=False),
        sa.Column("anonymous_id", sa.String(length=64), nullable=False),
        sa.Column("reason", sa.String(length=32), nullable=False),
        sa.Column("detail", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["post_id"], ["posts.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("post_id", "anonymous_id"),
    )


def downgrade() -> None:
    op.drop_table("post_reports")
    op.drop_index("ix_posts_author_created", table_name="posts")
    op.drop_column("posts", "removed_by")
    op.drop_column("posts", "removed_at")
