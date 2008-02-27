package EnsEMBL::Web::DBSQL::NewsAdaptor;

### SQL calls for connecting to the ENSEMBL_WEBSITE database and 
### selecting news-related data

use strict;
use warnings;
no warnings 'uninitialized';

use Class::Std;

use EnsEMBL::Web::SpeciesDefs;

{                              

sub new {
  my $caller = shift;
  my $r = shift;
  my $handle = shift;
  my $class = ref($caller) || $caller;
  my $self = { '_request' => $r };
  if ($EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY) {
    eval {
      ## Get the WebsiteDBAdaptor from the registry
      $self->{'_handle'} = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->websiteAdaptor();
    };
    unless($self->{'_handle'}) {
       warn( "Unable to connect to authentication database: $DBI::errstr" );
       $self->{'_handle'} = undef;
    }
    my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user();
    $self->{'_user'} = $user->id if $user;
  } else {
    if ($handle) {
      $self->{'_handle'} = $handle;
    } else {
      warn( "NO WEBSITE DATABASE DEFINED" );
      $self->{'_handle'} = undef;
    }
  }
  bless $self, $class;
  return $self;
}

sub handle {
  my $self = shift;
  return $self->{'_handle'};
}

sub editor {
  my $self = shift;
  return $self->{'_user'};
}


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
  return [] unless $self->handle;

  ## map option keywords to actual SQL
  my %where_def = (
    'item_id'=>'n.news_item_id = '.$where->{'item_id'},
    'release'=>'n.release_id = "'.$where->{'release'}.'"',
    'category'=>'n.news_category_id = '.$where->{'category'},
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
          $string .= "n.news_category_id = $id";
          $count++;
        }
        $string .= ')';
      }
    }
    else {
      $string .= "n.news_category_id = $cat";
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
            n.news_item_id      as news_item_id,
            n.release_id        as release_id,
            n.news_category_id  as news_category_id,
            n.title             as title,
            n.content           as content,
            n.priority          as priority,
            c.priority          as cat_order,
            n.status            as status
        FROM
            ( news_item n,
            news_category c )
  );
  if ($generic) {
    $sql .= qq(
        LEFT JOIN
            ( item_species i )
        ON
            ( n.news_item_id = i.news_item_id )
        WHERE
            i.news_item_id IS NULL
        AND
            n.news_category_id = c.news_category_id
    );
  }
  elsif ($where->{'species'} > 0) {
    $sql .= ', item_species i  WHERE n.news_category_id = c.news_category_id';
  }
  else {
    $sql .= ' WHERE n.news_category_id = c.news_category_id';
  }
  $sql .= " $where_str GROUP BY n.news_item_id ORDER BY n.priority DESC $limit_str";
  #warn $sql;

  my $T = $self->handle->selectall_arrayref($sql, {});
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
 
      my $X = $self->handle->selectall_arrayref($sql, {});

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
       'news_item_id'     => $A[0],
       'release_id'       => $A[1],
       'news_category_id' => $A[2],
       'title'            => $A[3],
       'content'          => $A[4],
       'priority'         => $A[5],
       'cat_order'        => $A[6],
       'status'           => $A[7],
       'species'          => $species,
       'sp_count'         => $sp_count
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
  return [] unless $self->handle;
  my $species = 0;
  if ($where->{'species'} && ref($where->{'species'}) eq 'ARRAY' && scalar(@{$where->{'species'}}) > 0) {
    $species = $where->{'species'};
  }

  ## add selected options to modifier strings
  my $where_str = ' AND n.release_id = "'.$where->{'release'}.'"';
  if ($species) {
    $where_str .= ' AND n.news_item_id = i.news_item_id  AND (';
    my $count = 0;
    foreach my $name (@$species) {
      $where_str .= ' OR ' if $count > 0;
      $where_str .= "s.name = '$name'";
      $count++;
    }
    $where_str .= ')';
  }

  my $limit_str = " LIMIT $limit " if $limit;

  ## build SQL
  my $sql = qq(
        SELECT
            n.news_item_id      as news_item_id,
            n.release_id        as release_id,
            n.news_category_id  as news_category_id,
            n.title             as title,
            n.content           as content,
            n.priority          as priority,
            c.priority          as cat_order,
            n.status            as status
        FROM
            news_item n,
            news_category c
  );
  if ($generic) {
    $sql .= qq(
        LEFT JOIN
            ( item_species i )
        ON
            ( n.news_item_id = i.news_item_id )
        WHERE
            i.news_item_id IS NULL
        AND
            n.news_category_id = c.news_category_id
    );
  }
  elsif ($species) {
    $sql .= ', item_species i, species s  WHERE n.news_category_id = c.news_category_id AND i.species_id = s.species_id ';
  }
  else {
    $sql .= ' WHERE n.news_category_id = c.news_category_id';
  }
  $sql .= " $where_str AND n.status = 'news_ok' GROUP BY n.news_item_id ORDER BY n.priority DESC $limit_str";

  my $T = $self->handle->selectall_arrayref($sql, {});
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
 
      my $X = $self->handle->selectall_arrayref($sql, {});

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
       'news_item_id'     => $A[0],
       'release_id'       => $A[1],
       'news_category_id' => $A[2],
       'title'            => $A[3],
       'content'          => $A[4],
       'priority'         => $A[5],
       'cat_order'        => $A[6],
       'status'           => $A[7],
       'species'          => $species,
       'sp_count'         => $sp_count
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
    return [] unless $self->handle;
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
    my $T = $self->handle->selectall_arrayref($sql, {});

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

    return {} unless $self->{'_handle'};

    my $sql;
    if ($release_id && $release_id ne 'all') {
        #warn "FETCHING SPECIES for RELEASE: " . $release_id;
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
        #warn "FETCHING ALL SPECIES";
        $sql = qq(
            SELECT
                s.species_id    as species_id,
                s.name          as species_name
            FROM
                species s
            ORDER BY species_name ASC
        );
    }

    my $T = $self->{'_handle'}->selectall_arrayref($sql);
    return {} unless $T;
    for (my $i=0; $i<scalar(@$T);$i++) {
        my @array = @{$T->[$i]};
        $$results{$array[0]} = $array[1];
    }
    return $results;
}

sub fetch_dump_info {
### Fetches dump notes and names of Ensembl species  
### Arguments (1) release id (integer)
### Returns arrayref of hashes containing species details

    my ($self, $release_id) = @_;
    my $results = [];

    return [] unless $release_id;
    return [] unless $self->{'_handle'};

    my $sql = qq(
            SELECT
                s.species_id,
                s.name,
                s.dump_notes
            FROM
                species s,
                release_species x
            WHERE   s.species_id = x.species_id
            AND     x.release_id = $release_id
            AND     x.assembly_code != ''
            ORDER BY name ASC
        );

    my $T = $self->{'_handle'}->selectall_arrayref($sql);
    return {} unless $T;
    for (my $i=0; $i<scalar(@$T);$i++) {
      my @array = @{$T->[$i]};
      push @$results, {
          'species_id'  => $array[0],
          'name'        => $array[1],
          'notes'       => $array[2],
      };
    }
    return $results;
}

sub fetch_species_id {
### Fetches ID of a named Ensembl species  
### Arguments: species name (string)
### Returns integer

    my ($self, $name) = @_;
    my $results = {};

    return unless $self->handle;
    return unless ($name && $name =~ /^[a-z]+_[a-z]+$/i);

    my $sql = qq(SELECT species_id FROM species WHERE name = "$name");

    my $T = $self->handle->selectrow_arrayref($sql);
    return unless $T;
    return $T->[0];
}

sub fetch_cats {
### Fetches names of Ensembl news categories 
### Returns arrayref of hashes containing category details

    my $self = shift;
    my $results = [];

    return [] unless $self->handle;

    my $sql = qq(
        SELECT
                c.news_category_id  as news_category_id,
                c.code              as news_category_code,
                c.name              as news_category_name
        FROM
                news_category c
        ORDER BY c.priority DESC
    );

    my $T = $self->handle->selectall_arrayref($sql);
    return [] unless $T;
    for (my $i=0; $i<scalar(@$T);$i++) {
        my @array = @{$T->[$i]};
        push (@$results,
            {
            'news_category_id'        => $array[0],
            'news_category_code'      => $array[1],
            'news_category_name'      => $array[2],
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

    return unless $self->handle;
    return unless ($string);
    

    my $sql = qq(SELECT news_category_id FROM news_category);
    if ($string =~ /^[a-z]+$/) { ## code values are single lower-case word
      $sql .= qq( WHERE code = "$string");
    }
    else {
      $sql .= qq( WHERE name = "$string");
    }

    my $T = $self->handle->selectrow_arrayref($sql);
    return unless $T;
    return $T->[0];
}

=pod
## OBSOLETE - now done by species_defs
sub fetch_random_ad {
  my $self = shift;
  return unless $self->handle;
                                                                                
  my $sql = qq(
    SELECT image, alt, url
    FROM miniad
    WHERE start_date < NOW() AND end_date > NOW()
    ORDER BY rand()
    LIMIT 1
  );
                                                                                
  my $record = $self->handle->selectall_arrayref($sql);
  return unless ($record && ref($record) eq 'ARRAY' && ref($record->[0]) eq 'ARRAY');
  my @array = @{$record->[0]};
  my $result = {
      'image' => $array[0],
      'alt'   => $array[1],
      'url'   => $array[2],
  };
  return $result;
}
=cut

sub fetch_species_data {

### Select query to get data for species lists, including vega, pre and previous release 
    my $self = shift;
    my $release_num = shift;
    my @results;

    return [] unless $self->handle;

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

    my $T = $self->handle->selectall_arrayref($sql);
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

    my $P = $self->handle->selectall_arrayref($sql);
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

    return [] unless $self->handle;

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

    my $T = $self->handle->selectall_arrayref($sql);
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

#----------------- Database admin queries ----------------------------------------

sub add_news_item {
    my ($self, $item_ref) = @_;
    my %item = %{$item_ref};

    my $release_id        = $item{'release_id'};
    my $title             = $item{'title'};
    my $content           = $item{'content'};
    my $news_category_id  = $item{'news_category_id'};
    my $species           = $item{'species_id'};
    my $priority          = $item{'priority'};
    my $status            = $item{'status'};
    my $user_id           = $self->editor;

    # escape double quotes in text items
    $title =~ s/"/\\"/g;
    $content =~ s/"/\\"/g;

    my $sql = qq(
        INSERT INTO
            news_item
        SET
            release_id        = "$release_id",
            title             = "$title",
            content           = "$content",
            news_category_id  = "$news_category_id",
            priority          = "$priority",
            status            = "$status",
            created_by        = $user_id,
            created_at        = NOW()
        );
#warn $sql;
    my $sth = $self->handle->prepare($sql);
    my $result = $sth->execute();

    # get id for inserted record
    $sql = "SELECT LAST_INSERT_ID()";
    my $T = $self->handle->selectall_arrayref($sql, {});
    return [] unless $T;
    my @A = @{$T->[0]}[0];
    my $id = $A[0];

    # don't forget species cross-referencing!
    if (scalar(@$species)) {
        foreach my $sp (@$species) {
            next unless $sp > 0;
            $sql = "INSERT INTO item_species (news_item_id, species_id) VALUES($id, $sp) ";
            $sth = $self->handle->prepare($sql);
            $result = $sth->execute();
        }
    }
  return $result;
}

sub update_news_item {
    my ($self, $item_ref) = @_;

    my %item = %{$item_ref};
    my $id                = $item{'news_item_id'};
    my $release_id        = $item{'release_id'};
    my $title             = $item{'title'};
    my $content           = $item{'content'};
    my $news_category_id  = $item{'news_category_id'};
    my $species           = $item{'species_id'};
    my $priority          = $item{'priority'};
    my $status            = $item{'status'};
    my $user_id           = $self->editor;
    $content =~ s/"/\\"/g;
    $content =~ s/'/\\'/g;

    my $sql = qq(
        UPDATE
            news_item
        SET
            release_id        = "$release_id",
            last_updated      = NOW(),
            title             = "$title",
            content           = "$content",
            news_category_id  = "$news_category_id",
            priority          = "$priority",
            status            = "$status",
            modified_by       = "$user_id",
            modified_at       = NOW()
        WHERE
            news_item_id = "$id"
        );
    my $sth = $self->handle->prepare($sql);
    my $result = $sth->execute();

    # update species/article cross-referencing
    $sql = qq(DELETE FROM item_species WHERE news_item_id = "$id");
    $sth = $self->handle->prepare($sql);
    $result = $sth->execute();

    foreach my $sp (@$species) {
        $sql = "INSERT INTO item_species (news_item_id, species_id) VALUES($id, $sp) ";
        $sth = $self->handle->prepare($sql);
        $result = $sth->execute();
    }
  return $result;
}

sub save_item_species {
  my ($self, $news_item, $species) = @_;
  return unless $news_item && $species;
  my $sql = qq(DELETE FROM item_species WHERE news_item_id = "$news_item");
  my $sth = $self->handle->prepare($sql);
  my $result = $sth->execute();

  foreach my $sp (@$species) {
    next if $sp eq '' || !defined($sp);
    $sql = "INSERT INTO item_species (news_item_id, species_id) VALUES ($news_item, $sp)";
    $sth = $self->handle->prepare($sql);
    $result = $sth->execute();
  }
  return $result;
}

sub add_release {
    my ($self, $record) = @_;
    my $result = '';

    return unless $self->handle;

    # check if record is already added
    my $release_id  = $$record{'release_id'};
    my $number      = $$record{'number'};
    my $date        = $$record{'date'};
    my $archive     = $$record{'archive'};

    my $sql = qq(SELECT release_id FROM ens_release WHERE number = "$number");

    my $T = $self->handle->selectall_arrayref($sql);

    unless ($T && @{$T->[0]}[0]) {
        # insert the new record
        $sql = qq(
            INSERT INTO
                ens_release
            SET release_id  = "$release_id",
                number      = "$number",
                date        = "$date",
                archive     = "$archive"
        );

        my $sth = $self->handle->prepare($sql);
        $result = $sth->execute();
    }
    return $result;
}

# Update release date - handy for slippage!

sub set_release_date {
    my ($self, $release, $date) = @_;
    my $result = '';

    return unless $self->handle;

    my $sql = qq(
        UPDATE ens_release
        SET date = "$date"
        WHERE release_id = "$release"
        );

    my $sth = $self->handle->prepare($sql);
    $result = $sth->execute();
    return $result;
}

# Add a record to the species table (record taken from an ini file)

sub add_species {
    my ($self, $record) = @_;
    my $result = '';

    return unless $self->handle;

    # check if record is already added
    my $name        = $$record{'name'};
    my $common_name = $$record{'common_name'};
    my $code        = $$record{'code'};

    my $sql = qq(SELECT species_id FROM species WHERE name = "$name" );

    my $T = $self->handle->selectall_arrayref($sql);

    unless ($T && @{$T->[0]}[0]) {
        # insert the new record
        $sql = qq(
            INSERT INTO
                species
            SET name = "$name",
                common_name = "$common_name",
                code = "$code"
        );

        my $sth = $self->handle->prepare($sql);
        $result = $sth->execute();
        if ($result) {
            # get id for inserted record
            $sql = "SELECT LAST_INSERT_ID()";
            $T = $self->handle->selectall_arrayref($sql, {});
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

  return unless $self->handle;
  return unless $record && ref($record) eq 'HASH';

  my $result = '';
  my $release_id      = $$record{'release_id'};
  my $species_id      = $$record{'species_id'};
  my $assembly_code   = $$record{'assembly_code'};
  my $assembly_name   = $$record{'assembly_name'};
  my $pre_code        = $$record{'pre_code'};
  my $pre_name        = $$record{'pre_name'};

  # check if record is already added
  my $sql = qq(SELECT release_id, species_id FROM release_species
          WHERE release_id = "$release_id" AND species_id = "$species_id");

  my $T = $self->handle->selectall_arrayref($sql);

  if ($T && @{$T->[0]}[0]) {
    ## update the existing record
    my $both = 0;
    $sql = qq(
        UPDATE
          release_species
        SET
    );
    if ($assembly_code || $assembly_name) {
      $sql .= qq(
            assembly_code = "$assembly_code",
            assembly_name = "$assembly_name"
      );
      $both = 1;
    }
    if ($pre_code || $pre_name) {
      $sql .= ',' if $both == 1;
      $sql .= qq(
            pre_code = "$pre_code",
            pre_name = "$pre_name"
      );
    }
    $sql .= qq(
        WHERE release_id = "$release_id" AND species_id = "$species_id"
    );
  }
  else {
    # insert the new record
    $sql = qq(
            INSERT INTO
                release_species
            SET release_id = "$release_id",
                species_id = "$species_id"
    );

    if ($assembly_code || $assembly_name) {
      $sql .= qq(,
            assembly_code = "$assembly_code",
            assembly_name = "$assembly_name"
      );
    }
    if ($pre_code || $pre_name) {
      $sql .= qq(,
            pre_code = "$pre_code",
            pre_name = "$pre_name"
      );
    }

  }
  my $sth = $self->handle->prepare($sql);
  $result = $sth->execute();
  if ($result) {
    $result = "Record added";
  }
  return $result;
}


}

1;


