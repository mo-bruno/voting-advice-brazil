"""Preserve electoral history while refreshing the published dataset."""

import sqlalchemy as sa

from alembic import op

revision = "0009_election_refresh"
down_revision = "0008_comment_admission_locks"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("candidates", sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()))
    op.add_column("candidates", sa.Column("official_status", sa.String(128), nullable=True))
    op.add_column("candidates", sa.Column("source_snapshot", sa.String(128), nullable=True))
    op.add_column("theses", sa.Column("editorial_id", sa.String(64), nullable=True))
    op.add_column("theses", sa.Column("editorial_version", sa.Integer(), nullable=True))
    op.create_index("uq_theses_editorial_version", "theses", ["election_year", "editorial_id", "editorial_version"], unique=True)
    op.add_column("candidate_positions", sa.Column("source_url", sa.String(1024), nullable=True))


def downgrade() -> None:
    op.drop_column("candidate_positions", "source_url")
    op.drop_index("uq_theses_editorial_version", table_name="theses")
    op.drop_column("theses", "editorial_version")
    op.drop_column("theses", "editorial_id")
    op.drop_column("candidates", "is_active")
    op.drop_column("candidates", "source_snapshot")
    op.drop_column("candidates", "official_status")
