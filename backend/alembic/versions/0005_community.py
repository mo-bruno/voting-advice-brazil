"""community_forum

Revision ID: 0005_community
Revises: 0004_iot_events
Create Date: 2026-05-30 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0005_community"
down_revision: Union[str, Sequence[str], None] = "0004_iot_events"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "posts",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("anonymous_id", sa.String(length=64), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("political_actor_id", sa.Integer(), nullable=True),
        sa.Column("theme_slug", sa.String(length=64), nullable=True),
        sa.Column("score", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["political_actor_id"],
            ["political_actors.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("posts") as batch_op:
        batch_op.create_index("ix_posts_anonymous_id", ["anonymous_id"])
        batch_op.create_index("ix_posts_score_created", ["score", "created_at"])
        batch_op.create_index("ix_posts_actor_id", ["political_actor_id"])

    op.create_table(
        "comments",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("post_id", sa.String(length=36), nullable=False),
        sa.Column("anonymous_id", sa.String(length=64), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["post_id"], ["posts.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("comments") as batch_op:
        batch_op.create_index("ix_comments_post_id", ["post_id"])

    op.create_table(
        "post_votes",
        sa.Column("post_id", sa.String(length=36), nullable=False),
        sa.Column("anonymous_id", sa.String(length=64), nullable=False),
        sa.Column("value", sa.SmallInteger(), nullable=False),
        sa.ForeignKeyConstraint(["post_id"], ["posts.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("post_id", "anonymous_id"),
    )

    op.create_table(
        "moderation_log",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("post_id", sa.String(length=36), nullable=True),
        sa.Column("anonymous_id", sa.String(length=64), nullable=False),
        sa.Column("content_hash", sa.String(length=64), nullable=False),
        sa.Column("approved", sa.Boolean(), nullable=False),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("model_used", sa.String(length=128), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("moderation_log") as batch_op:
        batch_op.create_index("ix_moderation_log_post_id", ["post_id"])


def downgrade() -> None:
    op.drop_table("moderation_log")
    op.drop_table("post_votes")
    with op.batch_alter_table("comments") as batch_op:
        batch_op.drop_index("ix_comments_post_id")
    op.drop_table("comments")
    with op.batch_alter_table("posts") as batch_op:
        batch_op.drop_index("ix_posts_actor_id")
        batch_op.drop_index("ix_posts_score_created")
        batch_op.drop_index("ix_posts_anonymous_id")
    op.drop_table("posts")
