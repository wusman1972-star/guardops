-- migrations/0008_shape_object.sql

-- 8. shape_object  (no primary key on source floor)
CREATE TABLE guardops.shape_object (
    account_id   bigint NOT NULL DEFAULT guardops.current_account(),
    picture_id   bigint NOT NULL,
    schema_name  text   NOT NULL,
    object_name  text   NOT NULL,
    object_kind  text   NOT NULL,
    column_shape jsonb  NOT NULL,
    row_estimate bigint,
    bytes        bigint,
    CONSTRAINT shape_object_picture_id_fkey FOREIGN KEY (picture_id) REFERENCES guardops.shape_picture (id)
);

CREATE INDEX shape_object_by_picture
    ON guardops.shape_object USING btree (picture_id);
