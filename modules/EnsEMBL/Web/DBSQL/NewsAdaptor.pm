package EnsEMBL::Web::DBSQL::NewsAdaptor;

### SQL calls for connecting to the ENSEMBL_WEBSITE database and 
### selecting news-related data

use strict;
use warnings;
no warnings 'uninitialized';

use DBI;
use EnsEMBL::Web::SpeciesDefs;
                              
sub new {
### c
  my( $class, $DB ) = @_;
  my $self = ref($DB) ? $DB : {}; ## don't crash site if no news db!
  bless $self, $class;
  return $self;
}

sub db {
### Opens a read-only MySQL database connection
  my $self = shift;
  $self->{'dbh'} ||= DBI->connect(
      "DBI:mysql:database=$self->{'NAME'};host=$self->{'HOST'};port=$self->{'PORT'}",
      $self->{'USER'}, "$self->{'PASS'}"
  );
  return $self->{'dbh'};
}
                                                                                
sub disconnect {
### Disconnects from the MySQL database
  my $self = shift;
  $self->{'dbh'}->disconnect if $self->{'dbh'};
}

sub DESTROY {
### d
  my $self = shift;
  #warn $self->disconnect;
}

############################## SELECT QUERIES #################################

#---------------------- QUERIES FOR NEWS_ITEM TABLE --------------------------

# This function needs to be able to do queries based on combinations
# of criteria (release, species, category and individual item), so that 
# it can be used as a general search as well as with the web admin interface

sub fetch_news_items {
### Runs a SELECT query to retrieve news items from the database
### Arguments (1) NewsAdaptor object; 
### (2) a hash reference of criteria and values - current valid criteria are item id, release,
### category, priority, species, status, and can be included in any combination
### (3) optional boolean flag indicating whether to select *only* those stories that apply to all species
### (4) optional integer - maximum number of records to return 
  my ($self, $where, $generic, $limit) = @_;
  my $results = [];
  return [] unless $self->db;

  ## map option keywords to actual SQL
  my %where_def = (
    'item_id'=>'n.news_item_id = '.$where->{'item_id'},
    'release'=>'n.release_id = "'.$where->{'release'}.'"',
    'category'=>'n.news_cat_id = '.$where->{'category'},
    'priority'=>'n.priority = '.$where->{'priority'},
    'status'=>'n.status = "'.$where->{'status'}.'"',
  );
  if (my $cat = $where->{'category'}) {
    my $string;
    if (ref($cat) eq 'ARRAY') {
      if (scalar(@$cat) > 0) {
        $string .= '(';
        my $count = 0;
        foreach my $id (@$cat) {
          $string .= ' OR ' if $count > 0;
          $string .= "n.news_cat_id = $id";
          $count++;
        }
        $string .= ')';
      }
    }
    else {
      $string .= "n.news_cat_id = $cat";
    }
    $where_def{'category'} = $string;
  }
  if (my $sp = $where->{'species'}) {
    my $string = 'n.news_item_id = i.news_item_id AND ';
    if (ref($sp) eq 'ARRAY') { 
      if (scalar(@$sp) > 0) {
        $string .= '(';
        my $count = 0;
        foreach my $id (@$sp) {
          $string .= ' OR ' if $count > 0;
          $string .= "i.species_id = $id";
          $count++;
        }
        $string .= ')';
      }
      else {
        $string = ''; ## empty array, so delete the criterion
      }
    }
    else {
      $string .= "i.species_id = $sp";
    }
    $where_def{'species'} = $string;
  }

  ## add selected options to modifier strings
  my $where_str;
  if ($where) {
    foreach my $param (keys %$where) {
      if ($where_def{$param}) {
        $where_str .= ' AND '.$where_def{$param}.' ';
      }
    }
  }

  my $limit_str = " LIMIT $limit " if $limit;

  ## build SQL
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
  if ($generic) {
    $sql .= qq(
        LEFT JOIN
            item_species i
        ON
            n.news_item_id = i.news_item_id
        WHERE
            i.news_item_id IS NULL
        AND
            n.news_cat_id = c.news_cat_id
    );
  }
  elsif ($where->{'species'} > 0) {
    $sql .= ', item_species i  WHERE n.news_cat_id = c.news_cat_id';
  }
  else {
    $sql .= ' WHERE n.news_cat_id = c.news_cat_id';
  }
  $sql .= " $where_str GROUP BY n.news_item_id ORDER BY n.priority DESC $limit_str";
#warn $sql;

  my $T = $self->db->selectall_arrayref($sql, {});
  return [] unless $T;

  my $running_total = scalar(@$T);
  for (my $i=0; $i<$running_total;$i++) {
    my @A = @{$T->[$i]};
    my $species = [];
    my $sp_count = 0;

    unless ($generic) {
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
       }
    );
  }
        
  return $results;
}

sub fetch_headlines {
### Alternative function to select news by category OR species
### Arguments (1) NewsAdaptor object; 
### (2) a hash reference of criteria and values - current valid criteria are release, species,
### (3) optional boolean flag indicating whether to select *only* those stories that apply to all species
### (4) optional integer - maximum number of records to return 
  my ($self, $where, $generic, $limit) = @_;
  my $results = [];
  return [] unless $self->db;

  my $string;
  if (my $sp = $where->{'species'}) {
    if (ref($sp) eq 'ARRAY') {
      if (scalar(@$sp) > 0) {
        $string .= '(';
        my $count = 0;
        foreach my $name (@$sp) {
          $string .= ' OR ' if $count > 0;
          $string .= "s.name = '$name'";
          $count++;
        }
        $string .= ')';
      }
      else {
        $string = undef; ## empty array, so delete the criterion
      }
    }
    else {
      $string .= "s.name = '$sp'";
    }
    $where_def{'species'} = $string;
  }

  ## add selected options to modifier strings
  my $where_str = ' AND n.release_id = "'.$where->{'release'}.'"';
  if ($where) {
    if ($where->{'species'}) {
      $where_str .= ' AND n.news_item_id = i.news_item_id ';
    }
    $where_str .= ' AND (';
    if ($where->{'species'}) {
      $where_str .= $string;
    }
    $where_str .= ')';
  }

  my $limit_str = " LIMIT $limit " if $limit;

  ## build SQL
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
  if ($generic) {
    $sql .= qq(
        LEFT JOIN
            item_species i
        ON
            n.news_item_id = i.news_item_id
        WHERE
            i.news_item_id IS NULL
        AND
            n.news_cat_id = c.news_cat_id
    );
  }
  elsif ($where->{'species'} > 0) {
    $sql .= ', item_species i, species s  WHERE n.news_cat_id = c.news_cat_id AND i.species_id = s.species_id ';
  }
  else {
    $sql .= ' WHERE n.news_cat_id = c.news_cat_id';
  }
  $sql .= " $where_str GROUP BY n.news_item_id ORDER BY n.priority DESC $limit_str";
#warn $sql;

  my $T = $self->db->selectall_arrayref($sql, {});
  return [] unless $T;

  my $running_total = scalar(@$T);
  for (my $i=0; $i<$running_total;$i++) {
    my @A = @{$T->[$i]};
    my $species = [];
    my $sp_count = 0;

    unless ($generic) {
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
       }
    );
  }
        
  return $results;
}



#--------------------- QUERIES FOR ADDITIONAL TABLES --------------------------

sub fetch_releases {
### Fetches details of Ensembl releases (date, etc) 
### Arguments (1) hashref of options - current valid keys are release and species
### Returns arrayref of hashes containing release details

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
                DATE_FORMAT(r.date, '%b %Y') as short_date,
                DATE_FORMAT(r.date, '%M %Y') as long_date
        FROM
                ens_release r);

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
            'short_date'        => $array[3],
            'long_date'         => $array[4]
            }
        );
    }
    return $results;
}

sub fetch_species {
### Fetches names of Ensembl species  
### Arguments (1) release id (integer)
### Returns arrayref of hashes containing species details

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
            AND     x.assembly_code != ''
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

sub fetch_species_id {
### Fetches ID of a named Ensembl species  
### Arguments: species name (string)
### Returns integer

    my ($self, $name) = @_;
    my $results = {};

    return unless $self->db;
    return unless ($name && $name =~ /^[a-z]+_[a-z]+$/i);

    my $sql = qq(SELECT species_id FROM species WHERE name = "$name");

    my $T = $self->db->selectrow_arrayref($sql);
    return unless $T;
    return $T->[0];
}

sub fetch_cats {
### Fetches names of Ensembl news categories 
### Returns arrayref of hashes containing category details

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

sub fetch_cat_id {
### Fetches ID of a category by code or name  
### Arguments: category code or name (string)
### Returns integer

    my ($self, $string) = @_;

    return unless $self->db;
    return unless ($string);
    

    my $sql = qq(SELECT news_cat_id FROM news_cat);
    if ($string =~ /^[a-z]+$/) { ## code values are single lower-case word
      $sql .= qq( WHERE code = "$string");
    }
    else {
      $sql .= qq( WHERE name = "$string");
    }

    my $T = $self->db->selectrow_arrayref($sql);
    return unless $T;
    return $T->[0];
}


sub fetch_random_ad {
  my $self = shift;
  return unless $self->db;
                                                                                
  my $sql = qq(
    SELECT image, alt, url
    FROM miniad
    WHERE start_date < NOW() AND end_date > NOW()
    ORDER BY rand()
    LIMIT 1
  );
                                                                                
  my $record = $self->db->selectall_arrayref($sql);
  return unless ($record && ref($record) eq 'ARRAY' && ref($record->[0]) eq 'ARRAY');
  my @array = @{$record->[0]};
  my $result = {
      'image' => $array[0],
      'alt'   => $array[1],
      'url'   => $array[2],
  };
  return $result;
}

sub fetch_species_data {

### Select query to get data for species lists, including vega, pre and previous release 
    my $self = shift;
    my $release_num = shift;
    my @results;

    return [] unless $self->db;

    my $sql = qq(
        SELECT 
                s.species_id, 
                s.name, 
                s.vega, 
                rs.assembly_name,
                rs.pre_name
        FROM 
                release_species rs,
                species s
        WHERE
                s.species_id = rs.species_id
                and release_id = $release_num
    );

    my $T = $self->db->selectall_arrayref($sql);
    return [] unless $T;

    for (my $i=0; $i<scalar(@$T);$i++) {
        my @array = @{$T->[$i]};
        $results[$array[0]] = {
            'name'      => $array[1],
            'vega'      => $array[2],
            'assembly'  => $array[3],
            'pre'       => $array[4],
          };
    }

    my $prev_rel = $release_num - 1;
    $sql = qq(
        SELECT
                s.species_id,
                rs.assembly_name,
                rs.pre_name
        FROM
                release_species rs,
                species s
        WHERE
                s.species_id = rs.species_id
                and release_id = $prev_rel

    );

    my $P = $self->db->selectall_arrayref($sql);
    return [] unless $P;

    for (my $i=0; $i<scalar(@$P);$i++) {
      my @array = @{$P->[$i]};
      my $sp_id = $array[0];
      if ($results[$sp_id]) {
        $results[$sp_id]{'prev_assembly'} = $array[1];
        $results[$sp_id]{'prev_pre'}      = $array[2];
      }
    }

    return \@results;
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


=head2 BUGS AND LIMITATIONS
                                                                                
None known at present.
                                                                                                                                                              
=head2 AUTHOR
                                                                                
Anne Parker, Ensembl Web Team
Support enquiries: helpdesk\@ensembl.org
                                                                                
=head2 COPYRIGHT
                                                                                
See http://www.ensembl.org/info/about/code_licence.html
                                                                                
=cut



