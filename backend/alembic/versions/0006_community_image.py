"""community_post_image

Revision ID: 0006_community_image
Revises: 0005_community
Create Date: 2026-05-31 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "0006_community_image"
down_revision: Union[str, Sequence[str], None] = "0005_community"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("posts") as batch_op:
        batch_op.add_column(sa.Column("image_data", sa.Text(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("posts") as batch_op:
        batch_op.drop_column("image_data")
