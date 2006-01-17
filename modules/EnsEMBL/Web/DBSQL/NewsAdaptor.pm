package EnsEMBL::Web::DBSQL::NewsAdaptor;

#--------------------------------------------------------------------------
# SQL calls for the "what's new" elements of the ENSEMBL_WEBSITE database
#--------------------------------------------------------------------------

use strict;
use warnings;
no warnings 'uninitialized';

use DBI;
use EnsEMBL::Web::SpeciesDefs;
                              
sub new {
  my( $class, $DB ) = @_;
  my $self = ref($DB) ? $DB : {}; ## don't crash site if no news db!
  bless $self, $class;
  return $self;
}

sub db {
  my $self = shift;
  $self->{'dbh'} ||= DBI->connect(
      "DBI:mysql:database=$self->{'NAME'};host=$self->{'HOST'};port=$self->{'PORT'}",
      $self->{'USER'}, "$self->{'PASS'}"
  );
  return $self->{'dbh'};
}
                                                                                
sub db_write {
  my $self = shift;
  my $SD = EnsEMBL::Web::SpeciesDefs->new;
  my $user = $SD->ENSEMBL_WRITE_USER;
  my $pass = $SD->ENSEMBL_WRITE_PASS;
  $self->{'dbh_write'} ||= DBI->connect(
    "DBI:mysql:database=$self->{'NAME'};host=$self->{'HOST'};port=$self->{'PORT'}",
    "$user", "$pass", { RaiseError => 1}
  );
  return $self->{'dbh_write'};
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
    my ($order_str, $sp_str, $group_str, $limit_str, %criteria, @order_by);
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
    
    my $limit = 0;
    if ($modifiers{'limit'}) {
        $limit = $modifiers{'limit'};
        $limit_str = " LIMIT $limit ";
    }

    # map option keywords to actual SQL
    my %crit_hash = (
        'item_id'=>'n.news_item_id = '.$criteria{'item_id'},
        'release'=>'n.release_id = '.$criteria{'release'},
        'category'=>'n.news_cat_id = '.$criteria{'category'},
        'priority'=>'n.priority = '.$criteria{'priority'},
        'species'=>'n.news_item_id = i.news_item_id AND i.species_id = '.$criteria{'species'},
        'status'=>'n.status = "'.$criteria{'status'}.'"',
        );
    my %order_hash = (
        'default'=>'n.priority DESC',
        'cat_desc'=>'c.priority DESC, n.priority DESC',
        'species'=>'i.species_id ASC',
        'release'=>'n.release_id DESC'
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
                n.priority       as priority,
                c.priority       as cat_order,
                n.status         as status
        FROM
                news_item n,
                news_cat c
    );
    if ($criteria{'species'} || $order_by_sp) {
        
        $sql .= ', item_species i ';
    }
    $sql .= " $crit_str $group_str $order_str $limit_str";
    my $T = $self->db->selectall_arrayref($sql, {});
    return [] unless $T;

    my $running_total = scalar(@$T);
    for (my $i=0; $i<$running_total;$i++) {
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
                'cat_order'     => $A[6],
                'status'        => $A[7],
                'species'       => $species,
                'sp_count'      => $sp_count
            });
    }
        
    if ($criteria{'species'} || $order_by_sp) {
    # also get stories that apply to all species
        my $continue = 1;        
        if ($limit) {
            my $running_limit = $limit - $running_total;
            if ($running_limit > 0) {
                $limit_str = " LIMIT $running_limit ";
            }
            else {
                $continue = 0;
            }
        }
        if ($continue) {
            $sql = qq(
                SELECT
                    n.news_item_id   as news_item_id,
                    n.release_id     as release_id,
                    n.news_cat_id    as news_cat_id,
                    n.title          as title,
                    n.content        as content,
                    n.priority       as priority,
                    c.priority       as cat_order,
                    n.status         as status
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
            $sql .= " $sp_str $order_str $limit_str ";
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
                    'cat_order'     => $A[6],
                    'status'        => $A[7],
                    'species'       => '',
                    'sp_count'      => '0'
                    });
            }
            if ($criteria{'species'}) {
                # re-sort records by release and then news category
                @$results = sort 
                        { $b->{'release_id'} <=> $a->{'release_id'} 
                          || $b->{'cat_order'} <=> $a->{'cat_order'}
                        } 
                        @$results;
            }
        }
    }

    return $results;
}


#--------------------- QUERIES FOR ADDITIONAL TABLES --------------------------

# Input: optional species arg
# Returns arrayref of results

sub fetch_releases {
    my ($self, $extra) = @_;
    my $results = [];
    return [] unless $self->db;
    my %option = %$extra if $extra;
    my $release = $option{'release'};
    my $species = $option{'species'};

    my $sql = qq(
        SELECT
                r.release_id    as release_id,
                r.number        as release_number,
                DATE_FORMAT(r.date, '%Y-%m-%d (%D %M %Y)') as full_date,
                DATE_FORMAT(r.date, '%b %Y') as short_date
        FROM
                release r);

    if ($release) {
        $sql .= qq( WHERE r.release_id = "$release" );
    }
    elsif ($species) {
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
    if ($release_id && $release_id ne 'all') {
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

#------------------------- Select queries for archive.ensembl.org -------------


# Input: release number
# Output:

sub fetch_assemblies {
    my $self = shift;
    my $release_num = shift;
    my $results = [];

    return [] unless $self->db;

    my $sql = qq(
        SELECT
                s.name, 
                rs.assembly_name
        FROM
                release_species rs, 
                species s
        WHERE
                s.species_id = rs.species_id 
                and release_id = $release_num

        ORDER BY s.name
    );

    my $T = $self->db->selectall_arrayref($sql);
    return [] unless $T;
    for (my $i=0; $i<scalar(@$T);$i++) {
        my @array = @{$T->[$i]};
        push (@$results,
            {
            'species'        => $array[0],
            'assembly_name'  => $array[1],
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
    my $status          = $item{'status'};

    # escape double quotes in text items
    $title =~ s/"/\\"/g;
    $content =~ s/"/\\"/g;

    my $sql = qq(
        INSERT INTO
            news_item
        SET
            release_id      = "$release_id",
            creation_date   = NOW(),
            title           = "$title",
            content         = "$content",
            news_cat_id     = "$news_cat_id",
            priority        = "$priority",
            status          = "$status"
        );
    my $sth = $self->db_write->prepare($sql);
    my $result = $sth->execute();

    # get id for inserted record
    $sql = "SELECT LAST_INSERT_ID()";
    my $T = $self->db_write->selectall_arrayref($sql, {});
    return [] unless $T;
    my @A = @{$T->[0]}[0];
    my $id = $A[0];

    # don't forget species cross-referencing!
    if (scalar(@$species)) {
        foreach my $sp (@$species) {
            next unless $sp > 0;
            $sql = "INSERT INTO item_species (news_item_id, species_id) VALUES($id, $sp) ";
            print $sql;
            $sth = $self->db_write->prepare($sql);
            $result = $sth->execute();
        }
    }
  return $result;
}

sub update_news_item {
    my ($self, $item_ref) = @_;
    
    my %item = %{$item_ref};
    my $id              = $item{'news_item_id'};
warn "ID $id";
    my $release_id      = $item{'release_id'};
    my $title           = $item{'title'};
    my $content         = $item{'content'};
    $content =~ s/"/\\"/g;
    $content =~ s/'/\\'/g;
    my $news_cat_id     = $item{'news_cat_id'};
    my $species         = $item{'species'};
    my $priority        = $item{'priority'};
    my $status          = $item{'status'};
warn "Species $species";
    my $sql = qq(
        UPDATE
            news_item
        SET
            release_id      = "$release_id",
            last_updated    = NOW(),
            title           = "$title",
            content         = "$content",
            news_cat_id     = "$news_cat_id",
            priority        = "$priority",
            status          = "$status"
        WHERE
            news_item_id = "$id"
        );
    my $sth = $self->db_write->prepare($sql);
    my $result = $sth->execute();

    # update species/article cross-referencing
    $sql = qq(DELETE FROM item_species WHERE news_item_id = "$id");
    $sth = $self->db_write->prepare($sql);
    $result = $sth->execute();

    foreach my $sp (@$species) {
        $sql = "INSERT INTO item_species (news_item_id, species_id) VALUES($id, $sp) ";
        $sth = $self->db_write->prepare($sql);
        $result = $sth->execute();
    }
  return $result;
}

#---------------- 2) Mostly used by the update_webdb.pl script ----------------

# Add a record to the release table (from ini file + optional user input)

sub add_release {
    my ($self, $record) = @_;
    my $result = '';

    return unless $self->db_write;

    # check if record is already added
    my $release_id  = $$record{'release_id'};
    my $number      = $$record{'number'};
    my $date        = $$record{'date'};
    my $archive     = $$record{'archive'};

    my $sql = qq(SELECT release_id FROM release WHERE number = "$number");

    my $T = $self->db_write->selectall_arrayref($sql);

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

        my $sth = $self->db_write->prepare($sql);
        $result = $sth->execute();
    }
    return $result;
}

# Update release date - handy for slippage!

sub set_release_date {
    my ($self, $release, $date) = @_;
    my $result = '';

    return unless $self->db_write;

    my $sql = qq(
        UPDATE release
        SET date = "$date"
        WHERE release_id = "$release"
        );
        
    my $sth = $self->db_write->prepare($sql);
    $result = $sth->execute();
    return $result;
}

# Add a record to the species table (record taken from an ini file)

sub add_species {
    my ($self, $record) = @_;
    my $result = '';

    return unless $self->db_write;

    # check if record is already added
    my $name        = $$record{'name'};
    my $common_name = $$record{'common_name'};
    my $code        = $$record{'code'};

    my $sql = qq(SELECT species_id FROM species WHERE name = "$name" );

    my $T = $self->db_write->selectall_arrayref($sql);

    unless ($T && @{$T->[0]}[0]) {
        # insert the new record
        $sql = qq(
            INSERT INTO 
                species
            SET name = "$name", 
                common_name = "$common_name", 
                code = "$code"
        );

        my $sth = $self->db_write->prepare($sql);
        $result = $sth->execute();
        if ($result) {
            # get id for inserted record
            $sql = "SELECT LAST_INSERT_ID()";
            $T = $self->db_write->selectall_arrayref($sql, {});
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

    return unless $self->db_write;

    # check if record is already added
    my $release_id      = $$record{'release_id'};
    my $species_id      = $$record{'species_id'};
    my $assembly_code   = $$record{'assembly_code'};
    my $assembly_name   = $$record{'assembly_name'};

    my $sql = qq(SELECT release_id, species_id FROM release_species 
                WHERE release_id = "$release_id" AND species_id = "$species_id");    

    my $T = $self->db_write->selectall_arrayref($sql);

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

        my $sth = $self->db_write->prepare($sql);
        $result = $sth->execute();
        if ($result) {
            $result = "Record added";
        }
    }
    return $result;
}



1;

__END__
                                                                                
=head1 Ensembl::Web::DBSQL::NewsAdaptor
                                                                                
=head2 SYNOPSIS
                                                                                
This package is called by a data object which needs to connect to the news tables in the ensembl_website database. E.g.
                                                                                
    use EnsEMBL::Web::DBSQL::NewsAdaptor;

    my $DB = $self->species_defs->databases->{'ENSEMBL_WEBSITE'};
    $self->__data->{'news_db'} = EnsEMBL::Web::DBSQL::NewsAdaptor->new( $DB );
                                                                                

=head2 DESCRIPTION
                                                                                
This class consists of methods for querying the ensembl_website database. This includes SELECT, INSERT and UPDATE queries, since the adaptor is used with a db admin interface as well as to retrieve news items for display.
                                                                                
=head2 METHODS

                                                                                
=head3 B<new>
                                                                                
Description: Constructor method

Arguments:    
                                                                                
Returns: EnsEMBL::Web::DBSQL::NewsAdaptor object

=head3 B<db>
                                                                                
Description: Connects to the required database using the normal (generally read-only) user

Arguments:     
                                                                                
Returns:  

=head3 B<db_write>
                                                                                
Description: Connects to the required database using a user with write privileges (assuming this is correctly configured in the ini file!)

Arguments:     
                                                                                
Returns:  

=head3 B<fetch_items>
                                                                                
Description: SELECT query which can take a number of modifying arguments

Arguments: a reference to a hash of query modifiers, with the following elements (all optional):
    $options = {
      'criteria'=>{hash of fields and their values},
      'order_by'=>[fields by which to order the results],
      'limit'=>integer
    };     
                                                                                
Returns: a reference to an array of hashes containing individual news stories. Note that the database stores a newsitem-to-species cross-reference only if a story applies to a limited number of species; stories relevant to all species have no cross-reference. Thus, queries for 'stories relevant to a given species' must be done in two steps: first stories with cross-references that match the species ID, then stories that have no cross-references at all. The user may thus need to re-sort the results after querying, if this is not the desired order.

=head3 B<fetch_releases>
                                                                                
Description: SELECT query

Arguments: a reference to a hash of form {'release'=>ID1, 'species'=>ID2} - both values are optional    
                                                                                
Returns:  a reference to a hash containing one or more release records. Each record contains the release ID, the release number, the full date [2005-12-31 (31stDecember 2005)] and the short date [Dec 2005]. 

=head3 B<fetch_species>
                                                                                
Description: SELECT query

Arguments: release ID (optional)    
                                                                                
Returns: a reference to a hash of species IDs and species names

=head3 B<fetch_cats>
                                                                                
Description: SELECT query

Arguments: none
                                                                                
Returns: a reference to an array of hashes contatining category IDs, codes and names, ordered by the 'priority' field in the database

=head3 B<fetch_assemblies>
                                                                                
Description: Used by the archive pages to get assembly names for species

Arguments: release ID (integer)
                                                                                
Returns: a reference to an array of hashes, each of form {'species'=>string, 'assembly_name'=>string}

=head3 B<add_news_item>
                                                                                
Description: INSERT query which adds a news record to the database

Arguments: a reference to a hash containing the database fields and values to be added    
                                                                                
Returns: none

=head3 B<update_news_item>
                                                                                
Description: UPDATE query for a news record

Arguments:  a reference to a hash containing the database fields and values to be updated       
                                                                                
Returns:  none

=head3 B<add_release>
                                                                                
Description: INSERT query for a release record

Arguments: a reference to a hash containing the database fields and values to be added        
                                                                                
Returns:  none

=head3 B<set_release_date>
                                                                                
Description: UPDATE query - used to reset release date when it slips

Arguments: release ID, date (in yyyy-mm-dd format)    
                                                                                
Returns:  none

=head3 B<add_species>
                                                                                
Description: INSERT query for a species record (e.g. from an ini file). The handler checks if the species is already listed in the database

Arguments: a reference to a record hash ([scientific] name, common name, [2-letter] code)
                                                                                
Returns:  ID for new record (integer)

=head3 B<add_release_species>
                                                                                
Description: INSERT query - adds a record to the release_species cross-reference table. Can be used as part of a db update script to add all current species to a new release

Arguments:  a reference to a record hash holding the release ID, species ID, species code [Ensembl internal Golden Path ID] and assembly name
                                                                                
Returns:  a status message (string) 


=head2 BUGS AND LIMITATIONS
                                                                                
None known at present.
                                                                                                                                                              
=head2 AUTHOR
                                                                                
Anne Parker, Ensembl Web Team
Support enquiries: helpdesk\@ensembl.org
                                                                                
=head2 COPYRIGHT
                                                                                
See http://www.ensembl.org/info/about/code_licence.html
                                                                                
=cut



