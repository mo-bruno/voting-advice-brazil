"""iot_device_events

Revision ID: 0004_iot_events
Revises: 0003_iot_device_pairing
Create Date: 2026-05-27 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "0004_iot_events"
down_revision: Union[str, Sequence[str], None] = "0003_iot_device_pairing"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "iot_device_events",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("device_token", sa.String(length=64), nullable=False),
        sa.Column("event_type", sa.String(length=32), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("iot_device_events", schema=None) as batch_op:
        batch_op.create_index(
            "ix_iot_device_events_token_type_at",
            ["device_token", "event_type", "published_at"],
            unique=False,
        )


def downgrade() -> None:
    with op.batch_alter_table("iot_device_events", schema=None) as batch_op:
        batch_op.drop_index("ix_iot_device_events_token_type_at")
    op.drop_table("iot_device_events")
