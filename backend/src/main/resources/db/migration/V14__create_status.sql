-- 24-hour photo statuses (spec §8.1). Reads filter on expires_at, so an expired status is never
-- served even before the reaper deletes it. media_id has no foreign key: the photo is purged
-- through the StatusExpired event once the status is gone.
create table status (
  id          uuid primary key,
  owner_id    uuid not null references account(id),
  media_id    uuid not null,
  caption     varchar(100),
  created_at  timestamptz not null,
  expires_at  timestamptz not null,
  updated_at  timestamptz not null
);
create index status_owner_live on status (owner_id, expires_at);
create index status_expiry on status (expires_at);

create table status_view (
  status_id  uuid not null references status(id) on delete cascade,
  viewer_id  uuid not null references account(id),
  viewed_at  timestamptz not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  primary key (status_id, viewer_id)
);
create index status_view_viewer on status_view (viewer_id);
