"""Preserve the plan analysis separately from the scoreable position.

Revision ID: 0011_candidate_position_analysis
Revises: 0010_politician_follow_interest
Create Date: 2026-09-30 00:00:00.000000
"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "0011_candidate_position_analysis"
down_revision: Union[str, Sequence[str], None] = "0010_politician_follow_interest"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "candidate_positions",
        sa.Column("analytical_position", sa.String(length=32), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("candidate_positions", "analytical_position")
