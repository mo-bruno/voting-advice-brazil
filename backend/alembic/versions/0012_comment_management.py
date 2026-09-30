"""Retain comment tombstones and deduplicated reports without changing discussion."""

import sqlalchemy as sa

from alembic import op

revision: str = "0012_comment_management"
down_revision: str = "0011_candidate_position_analysis"
branch_labels: str | None = None
depends_on: str | None = None


def upgrade() -> None:
    op.add_column(
        "comments", sa.Column("removed_at", sa.DateTime(timezone=True), nullable=True)
    )
    op.add_column("comments", sa.Column("removed_by", sa.String(16), nullable=True))
    op.create_table(
        "comment_reports",
        sa.Column("comment_id", sa.String(36), nullable=False),
        sa.Column("anonymous_id", sa.String(64), nullable=False),
        sa.Column("reason", sa.String(32), nullable=False),
        sa.Column("detail", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["comment_id"], ["comments.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("comment_id", "anonymous_id"),
    )


def downgrade() -> None:
    op.drop_table("comment_reports")
    op.drop_column("comments", "removed_by")
    op.drop_column("comments", "removed_at")
