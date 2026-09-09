"""Add per-device event delivery deduplication without changing historical events."""

import sqlalchemy as sa

from alembic import op

revision: str = "0007_iot_event_deduplication"
down_revision: str = "0006_community_integrity"
branch_labels: str | None = None
depends_on: str | None = None


def upgrade() -> None:
    with op.batch_alter_table("iot_device_events") as batch_op:
        batch_op.add_column(sa.Column("deduplication_key", sa.String(192), nullable=True))
        batch_op.create_unique_constraint(
            "uq_iot_events_delivery", ["device_token", "event_type", "deduplication_key"]
        )


def downgrade() -> None:
    with op.batch_alter_table("iot_device_events") as batch_op:
        batch_op.drop_constraint("uq_iot_events_delivery", type_="unique")
        batch_op.drop_column("deduplication_key")
