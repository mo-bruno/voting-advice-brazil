"""iot_device_pairing

Revision ID: 0003_iot_device_pairing
Revises: 0002_public_actor_tracker
Create Date: 2026-05-22 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0003_iot_device_pairing"
down_revision: Union[str, Sequence[str], None] = "0002_public_actor_tracker"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "iot_device_links",
        sa.Column("device_token", sa.String(length=64), nullable=False),
        sa.Column("anonymous_id", sa.String(length=64), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("device_token"),
        sa.UniqueConstraint("anonymous_id", name="uq_iot_device_links_anonymous_id"),
    )
    with op.batch_alter_table("iot_device_links", schema=None) as batch_op:
        batch_op.create_index(
            "ix_iot_device_links_anonymous_id",
            ["anonymous_id"],
            unique=False,
        )
        batch_op.create_index(
            "ix_iot_device_links_updated_at",
            ["updated_at"],
            unique=False,
        )

    op.create_table(
        "iot_pairing_sessions",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("device_token", sa.String(length=64), nullable=False),
        sa.Column("pairing_code_hash", sa.String(length=128), nullable=False),
        sa.Column("qr_payload", sa.String(length=512), nullable=False),
        sa.Column("firmware_version", sa.String(length=32), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("iot_pairing_sessions", schema=None) as batch_op:
        batch_op.create_index(
            "ix_iot_pairing_sessions_device_expires",
            ["device_token", "expires_at"],
            unique=False,
        )


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("iot_pairing_sessions", schema=None) as batch_op:
        batch_op.drop_index("ix_iot_pairing_sessions_device_expires")

    op.drop_table("iot_pairing_sessions")

    with op.batch_alter_table("iot_device_links", schema=None) as batch_op:
        batch_op.drop_index("ix_iot_device_links_updated_at")
        batch_op.drop_index("ix_iot_device_links_anonymous_id")

    op.drop_table("iot_device_links")
