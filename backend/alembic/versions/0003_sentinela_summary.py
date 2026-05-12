"""sentinela_summary

Revision ID: 0003_sentinela_summary
Revises: 0002_public_actor_tracker
Create Date: 2026-05-12 12:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "0003_sentinela_summary"
down_revision: Union[str, Sequence[str], None] = "0002_public_actor_tracker"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "sentinela_summaries",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("political_actor_id", sa.Integer(), nullable=False),
        sa.Column("period", sa.String(length=16), nullable=False),
        sa.Column("generated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("votes_summary", sa.Text(), nullable=False),
        sa.Column("propositions_summary", sa.Text(), nullable=False),
        sa.Column("expenses_summary", sa.Text(), nullable=False),
        sa.Column("synthesis", sa.Text(), nullable=False),
        sa.ForeignKeyConstraint(["political_actor_id"], ["political_actors.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "political_actor_id", "period",
            name="uq_sentinela_summaries_actor_period",
        ),
    )
    with op.batch_alter_table("sentinela_summaries", schema=None) as batch_op:
        batch_op.create_index(
            "ix_sentinela_summaries_actor_period",
            ["political_actor_id", "period"],
            unique=False,
        )


def downgrade() -> None:
    with op.batch_alter_table("sentinela_summaries", schema=None) as batch_op:
        batch_op.drop_index("ix_sentinela_summaries_actor_period")
    op.drop_table("sentinela_summaries")
