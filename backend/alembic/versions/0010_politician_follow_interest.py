"""politician_follow_interest

Revision ID: 0010_politician_follow_interest
Revises: 0009_election_refresh
Create Date: 2026-09-29 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "0010_politician_follow_interest"
down_revision: Union[str, Sequence[str], None] = "0009_election_refresh"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "politician_follow_interests",
        sa.Column("subject_hash", sa.String(length=64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("subject_hash"),
    )


def downgrade() -> None:
    op.drop_table("politician_follow_interests")
