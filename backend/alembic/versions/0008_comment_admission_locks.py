"""Serialize comment admission per anonymous author without changing comments."""

import sqlalchemy as sa

from alembic import op

revision: str = "0008_comment_admission_locks"
down_revision: str = "0007_iot_event_deduplication"
branch_labels: str | None = None
depends_on: str | None = None


def upgrade() -> None:
    op.create_table(
        "comment_admission_locks",
        sa.Column("anonymous_id", sa.String(64), primary_key=True),
    )


def downgrade() -> None:
    op.drop_table("comment_admission_locks")
