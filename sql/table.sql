
create table genomic_align_block (
       align_id     integer(10) NOT NULL,
       align_start  integer(10) NOT NULL,
       align_end    integer(10) NOT NULL,
       align_row    integer(10) NOT NULL,
       raw_id       varchar(40) NOT NULL,
       raw_start    integer(10) NOT NULL,
       raw_end      integer(10) NOT NULL,
       raw_strand   integer(10) NOT NULL,

       PRIMARY KEY (align_id,align_start,align_end,raw_id),
       KEY (raw_id,raw_start,raw_end),
       KEY (raw_id,raw_end)
       );
