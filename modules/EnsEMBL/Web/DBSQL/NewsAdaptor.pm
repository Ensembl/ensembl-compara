package EnsEMBL::Web::DBSQL::NewsAdaptor;

#--------------------------------------------------------------------------
# SQL calls for the "what's new" elements of the ENSEMBL_WEBSITE database
#--------------------------------------------------------------------------

use strict;
use warnings;
no warnings 'uninitialized';

use DBI;
                                                                                
sub new {
  my( $class, $DB ) = @_;
  my $dbh;
  my $self = $DB;
  bless $self, $class;
  return $self;
}
                                                                                
sub db {
  my $self = shift;
  $self->{'dbh'} ||= DBI->connect(
    "DBI:mysql:database=$self->{'NAME'};host=$self->{'HOST'};port=$self->{'PORT'}",
    $self->{'USER'}, "$self->{'PASS'}", { RaiseError => 1}
  );
  return $self->{'dbh'};
}

############################## SELECT QUERIES #################################

#---------------------- QUERIES FOR NEWS_ITEM TABLE --------------------------

# This function needs to be able to do queries based on combinations
# of criteria (release, species, category and individual item), so that 
# it can be used as a general search as well as with the web admin interface

sub fetch_items {
    my ($self, $options) = @_;
    my $results = [];
    return [] unless $self->db;

    my %modifiers = %{$options};
    my $crit_str = ' WHERE n.news_cat_id = c.news_cat_id ';
    my ($order_str, $sp_str, $group_str, %criteria, @order_by);
    if (ref($modifiers{'criteria'})) {
        %criteria = %{$modifiers{'criteria'}};
    }
    if (ref($modifiers{'order_by'})) {
        @order_by = @{$modifiers{'order_by'}};
        if (scalar(@order_by) < 1) {
            @order_by = ('default');
        }
    }
    else {
        @order_by = ('default');
    }
    my $order_by_sp;
    
    # map option keywords to actual SQL
    my %crit_hash = (
        'item_id'=>'n.news_item_id = '.$criteria{'item_id'},
        'release'=>'n.release_id = '.$criteria{'release'},
        'category'=>'n.news_cat_id = '.$criteria{'category'},
        'priority'=>'n.priority = '.$criteria{'priority'},
        'species'=>'n.news_item_id = i.news_item_id AND i.species_id = '.$criteria{'species'},
        );
    my %order_hash = (
        'default'=>'n.priority DESC',
        'cat_desc'=>'c.priority DESC, n.priority DESC',
        'species'=>'i.species_id ASC'
        );

    # add selected options to modifier strings
    if (%criteria) {
        foreach my $criterion (keys %criteria) {
            $crit_str .= ' AND '.$crit_hash{$criterion}.' ';
            $sp_str .= ' AND '.$crit_hash{$criterion}.' ' unless ($criterion eq 'species');
        }
    }
    if (@order_by) {
        $order_str = ' ORDER BY ';
        my $count = 0;
        foreach my $order (@order_by) {
            $order_str .= $order_hash{$order};
            unless ($count == $#order_by) {
                $order_str .= ', ';
            }
            if ($order eq 'species') {
                $order_by_sp = 1;
                $crit_str .= ' AND n.news_item_id = i.news_item_id ';
                $group_str = ' GROUP BY n.news_item_id ';
            }
            $count++;
        }
    }

    my $sql = qq(
        SELECT
                n.news_item_id   as news_item_id,
                n.release_id     as release_id,
                n.news_cat_id    as news_cat_id,
                n.title          as title,
                n.content        as content,
                n.priority       as priority
        FROM
                news_item n,
                news_cat c
    );
    if ($criteria{'species'} || $order_by_sp) {
        $sql .= ', item_species i ';
    }
    $sql .= " $crit_str $group_str $order_str";
    my $T = $self->db->selectall_arrayref($sql, {});
    return [] unless $T;

    for (my $i=0; $i<scalar(@$T);$i++) {
        my @A = @{$T->[$i]};
        my $species = [];
        my $sp_count = 0;

        unless ($criteria{'species'}) {
        # get species list for each item
            my $id = $A[0];
            $sql = qq(
                SELECT
                    s.species_id        as species_id
                FROM
                    species s,
                    item_species i
                WHERE   s.species_id = i.species_id
                AND     i.news_item_id = $id
                );
 
            my $X = $self->db->selectall_arrayref($sql, {});

            if ($X && $X->[0]) {
                $sp_count = scalar(@$X);
                for (my $j=0; $j<$sp_count;$j++) {
                    my @B = @{$X->[$j]};
                    push (@$species, $B[0]);
                }
            }
        }
        push (@$results,
            {
                'news_item_id'  => $A[0],
                'release_id'    => $A[1],
                'news_cat_id'   => $A[2],
                'title'         => $A[3],
                'content'       => $A[4],
                'priority'      => $A[5],
                'species'       => $species,
                'sp_count'      => $sp_count
            });
    }
        
    if ($criteria{'species'} || $order_by_sp) {
    # also get stories that apply to all species
        $sql = qq(
            SELECT
                n.news_item_id   as news_item_id,
                n.release_id     as release_id,
                n.news_cat_id    as news_cat_id,
                n.title          as title,
                n.content        as content,
                n.priority       as priority
            FROM
                news_item n,
                news_cat c
            LEFT JOIN
                item_species i
            ON
                n.news_item_id = i.news_item_id
            WHERE
                i.news_item_id IS NULL
            AND 
                n.news_cat_id = c.news_cat_id 
            );
        $sql .= " $sp_str $order_str";
        $T = $self->db->selectall_arrayref($sql, {});
        return [] unless $T;

        for (my $i=0; $i<scalar(@$T);$i++) {
            my @A = @{$T->[$i]};
            push (@$results,
                {
                'news_item_id'  => $A[0],
                'release_id'    => $A[1],
                'news_cat_id'   => $A[2],
                'title'         => $A[3],
                'content'       => $A[4],
                'priority'      => $A[5],
                'species'       => '',
                'sp_count'      => '0'
                });
        }
    }

    return $results;
}


#--------------------- QUERIES FOR ADDITIONAL TABLES --------------------------

sub fetch_releases {
    my ($self, $species) = @_;
    my $results = [];

    return [] unless $self->db;

    my $sql = qq(
        SELECT
                r.release_id    as release_id,
                r.number        as release_number,
                DATE_FORMAT(r.date, '%Y-%m-%d (%D %M %Y)') as full_date,
                DATE_FORMAT(r.date, '%b %Y') as short_date
        FROM
                release r);

    if ($species) {
        $sql .= qq(, release_species s 
                WHERE
                    r.release_id = s.release_id 
                AND 
                    s.species_id = "$species");
    }
    $sql .= qq( ORDER BY release_id DESC);
    my $T = $self->db->selectall_arrayref($sql, {});

    return [] unless $T;
    for (my $i=0; $i<scalar(@$T);$i++) {
        my @array = @{$T->[$i]};
        push (@$results,
            {
            'release_id'        => $array[0],
            'release_number'    => $array[1],
            'full_date'         => $array[2],
            'short_date'        => $array[3]
            }
        );
    }
    return $results;
}

sub fetch_species {
    my ($self, $release_id) = @_;
    my $results = {};

    return {} unless $self->db;

    my $sql;
    if ($release_id) {
        $sql = qq(
            SELECT
                s.species_id    as species_id,
                s.name          as species_name
            FROM
                species s,
                release_species x
            WHERE   s.species_id = x.species_id
            AND     x.release_id = $release_id
            ORDER BY species_name ASC
        );
    } else {
        $sql = qq(
            SELECT
                s.species_id    as species_id,
                s.name          as species_name
            FROM
                species s
            ORDER BY species_name ASC
        );
    }

    my $T = $self->db->selectall_arrayref($sql);
    return {} unless $T;
    for (my $i=0; $i<scalar(@$T);$i++) {
        my @array = @{$T->[$i]};
        $$results{$array[0]} = $array[1];
    }
    return $results;
}

sub fetch_cats {
    my $self = shift;
    my $results = [];

    return [] unless $self->db;

    my $sql = qq(
        SELECT
                c.news_cat_id    as news_cat_id,
                c.code           as news_cat_code,
                c.name           as news_cat_name
        FROM
                news_cat c
        ORDER BY c.priority DESC
    );

    my $T = $self->db->selectall_arrayref($sql);
    return [] unless $T;
    for (my $i=0; $i<scalar(@$T);$i++) {
        my @array = @{$T->[$i]};
        push (@$results,
            {
            'news_cat_id'        => $array[0],
            'news_cat_code'      => $array[1],
            'news_cat_name'      => $array[2],
            }
        );
    }
    return $results;
}

#------------------------ DATABASE ADMIN QUERIES -------------------------------

#---------------- 1) For use with web front end --------------------------------

sub add_news_item {
    my ($self, $item_ref) = @_;
    my %item = %{$item_ref};

    my $release_id      = $item{'release_id'};
    my $title           = $item{'title'};
    my $content         = $item{'content'};
    my $news_cat_id     = $item{'news_cat_id'};
    my $species         = $item{'species'};
    my $priority        = $item{'priority'};

    # escape double quotes in text items
    $title =~ s/"/\\"/g;
    $content =~ s/"/\\"/g;

    my $sql = qq(
        INSERT INTO
            news_item
        SET
            release_id      = "$release_id",
            date            = NOW(),
            title           = "$title",
            content         = "$content",
            news_cat_id     = "$news_cat_id",
            priority        = "$priority"
        );
    my $sth = $self->db->prepare($sql);
    my $result = $sth->execute();

    # get id for inserted record
    $sql = "SELECT LAST_INSERT_ID()";
    my $T = $self->db->selectall_arrayref($sql, {});
    return [] unless $T;
    my @A = @{$T->[0]}[0];
    my $id = $A[0];

    # don't forget species cross-referencing!
    foreach my $sp (@$species) {
        $sql = "INSERT INTO item_species (news_item_id, species_id) VALUES($id, $sp) ";
        $sth = $self->db->prepare($sql);
        $result = $sth->execute();
    }
}

sub update_news_item {
    my ($self, $item_ref) = @_;
    
    my %item = %{$item_ref};
    my $id              = $item{'news_item_id'};
    my $release_id      = $item{'release_id'};
    my $title           = $item{'title'};
    my $content         = $item{'content'};
    $content =~ s/"/\\"/g;
    $content =~ s/'/\\'/g;
    my $news_cat_id     = $item{'news_cat_id'};
    my $species         = $item{'species'};
    my $priority        = $item{'priority'};

    my $sql = qq(
        UPDATE
            news_item
        SET
            release_id    = "$release_id",
            date            = NOW(),
            title           = "$title",
            content         = "$content",
            news_cat_id     = "$news_cat_id",
            priority        = "$priority"
        WHERE
            news_item_id = "$id"
        );
    my $sth = $self->db->prepare($sql);
    my $result = $sth->execute();

    # update species/article cross-referencing
    $sql = qq(DELETE FROM item_species WHERE news_item_id = "$id");
    $sth = $self->db->prepare($sql);
    $result = $sth->execute();

    foreach my $sp (@$species) {
        $sql = "INSERT INTO item_species (news_item_id, species_id) VALUES($id, $sp) ";
        $sth = $self->db->prepare($sql);
        $result = $sth->execute();
    }
}

#---------------- 2) Mostly used by the update_webdb.pl script ----------------

# Add a record to the release table (from ini file + optional user input)

sub add_release {
    my ($self, $record) = @_;
    my $result = '';

    return unless $self->db;

    # check if record is already added
    my $release_id  = $$record{'release_id'};
    my $number      = $$record{'number'};
    my $date        = $$record{'date'};
    my $archive     = $$record{'archive'};

    my $sql = qq(SELECT release_id FROM release WHERE number = "$number");

    my $T = $self->db->selectall_arrayref($sql);

    unless ($T && @{$T->[0]}[0]) {
        # insert the new record
        $sql = qq(
            INSERT INTO 
                release
            SET release_id  = "$release_id", 
                number      = "$number", 
                date        = "$date",
                archive     = "$archive"
        );

        my $sth = $self->db->prepare($sql);
        $result = $sth->execute();
    }
    return $result;
}

# Update release date - handy for slippage!

sub set_release_date {
    my ($self, $release, $date) = @_;
    my $result = '';

    return unless $self->db;

    my $sql = qq(
        UPDATE release
        SET date = "$date"
        WHERE release_id = "$release"
        );
        
    my $sth = $self->db->prepare($sql);
    $result = $sth->execute();
    return $result;
}

# Add a record to the species table (record taken from an ini file)

sub add_species {
    my ($self, $record) = @_;
    my $result = '';

    return unless $self->db;

    # check if record is already added
    my $name        = $$record{'name'};
    my $common_name = $$record{'common_name'};
    my $code        = $$record{'code'};

    my $sql = qq(SELECT species_id FROM species WHERE name = "$name" );

    my $T = $self->db->selectall_arrayref($sql);

    unless ($T && @{$T->[0]}[0]) {
        # insert the new record
        $sql = qq(
            INSERT INTO 
                species
            SET name = "$name", 
                common_name = "$common_name", 
                code = "$code"
        );

        my $sth = $self->db->prepare($sql);
        $result = $sth->execute();
        if ($result) {
            # get id for inserted record
            $sql = "SELECT LAST_INSERT_ID()";
            $T = $self->db->selectall_arrayref($sql, {});
            return '' unless $T;
            my @A = @{$T->[0]}[0];
            $result = $A[0];
        }
    }
    return $result;
}

# Add a record to the release_species cross-reference table

sub add_release_species {
    my ($self, $record) = @_;
    my $result = '';

    return unless $self->db;

    # check if record is already added
    my $release_id      = $$record{'release_id'};
    my $species_id      = $$record{'species_id'};
    my $assembly_code   = $$record{'assembly_code'};
    my $assembly_name   = $$record{'assembly_name'};

    my $sql = qq(SELECT release_id, species_id FROM release_species 
                WHERE release_id = "$release_id" AND species_id = "$species_id");    

    my $T = $self->db->selectall_arrayref($sql);

    if ($T && @{$T->[0]}[0]) {
        $result = "This species is already logged for release $release_id";
    }
    else {
        # insert the new record
        $sql = qq(
            INSERT INTO 
                release_species
            SET release_id = "$release_id", 
                species_id = "$species_id", 
                assembly_code = "$assembly_code",
                assembly_name = "$assembly_name"
        );

        my $sth = $self->db->prepare($sql);
        $result = $sth->execute();
        if ($result) {
            $result = "Record added";
        }
    }
    return $result;
}

1;

