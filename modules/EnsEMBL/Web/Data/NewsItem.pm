package EnsEMBL::Web::Data::NewsItem;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);
use EnsEMBL::Web::RegObj;

__PACKAGE__->table('news_item');
__PACKAGE__->set_primary_key('news_item_id');

__PACKAGE__->add_queriable_fields(
  title       => 'tinytext',
  content     => 'text',
  declaration => 'text',
  notes       => 'text',
  priority    => 'int',
  status      => "enum('declared','handed_over','postponed','cancelled')",
  news_done   => "enum('N','Y')",
);

__PACKAGE__->add_fields(
  team              => "enum('Compara','Core','Funcgen','Genebuild','Mart','Outreach','Variation','Web')",
  assembly          => "enum('N','Y')",
  gene_set          => "enum('N','Y')",
  repeat_masking    => "enum('N','Y')",
  stable_id_mapping => "enum('N','Y')",
  affy_mapping      => "enum('N','Y')",
  database          => "enum('new','patched')",
);


__PACKAGE__->columns(TEMP => 'category_name');

__PACKAGE__->has_a(release       => 'EnsEMBL::Web::Data::Release');
__PACKAGE__->has_a(news_category => 'EnsEMBL::Web::Data::NewsCategory');
__PACKAGE__->has_many(species    => 'EnsEMBL::Web::Data::Species');


__PACKAGE__->set_sql(news_items => qq{
  SELECT DISTINCT
      n.*,
      c.name AS category_name
  FROM
      __TABLE(=n)__
      LEFT JOIN
      __TABLE(EnsEMBL::Web::Data::ItemSpecies=i)__ ON n.news_item_id = i.news_item_id,
      __TABLE(EnsEMBL::Web::Data::NewsCategory=c)__
  WHERE
      n.news_category_id = c.news_category_id
      %s                   -- where
      %s %s                -- order and limit
});

__PACKAGE__->set_sql(create_item => qq{
  INSERT INTO
    __TABLE__
  SET 
    news_item_id = NULL,
    release_id = ?,
    declaration = ?,
    data = ?,
    notes = ?,
    title = ?,
    content = ?,
    news_category_id = ?,  
    priority = ?,
    status = ?,
    news_done = ?,
    created_by = ?,
    created_at = NOW() 
});

__PACKAGE__->set_sql(update_item => qq{
  UPDATE 
    __TABLE__
  SET 
    release_id = ?,
    declaration = ?,
    data = ?,
    notes = ?,
    title = ?,
    content = ?,
    news_category_id = ?,  
    priority = ?,
    status = ?,
    news_done = ?,
    modified_by = ?,
    modified_at = NOW()
  WHERE
    news_item_id = ? 
});

__PACKAGE__->set_sql(add_species => qq{
  INSERT INTO
    item_species
  SET
    species_id = ?,
    news_item_id = ?
});

__PACKAGE__->set_sql(delete_species => qq{
  DELETE FROM
    item_species
  WHERE
    news_item_id = ?
});

__PACKAGE__->set_sql(get_species => qq{
  SELECT 
    species_id 
  FROM
    item_species
  WHERE
    news_item_id = ?
});

sub save {
### Override parent save in order to cope with many-to-many relationship
  my $self = shift;
  my $id = shift;
  my $species = shift || [];
  my $sth;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;

  my $data = {
    team              => $self->team,
    assembly          => $self->assembly,
    gene_set          => $self->gene_set,
    repeat_masking    => $self->repeat_masking,
    stable_id_mapping => $self->stable_id_mapping,
    affy_mapping      => $self->affy_mapping,
    database          => $self->database
  };
  my $data_string = $self->dump_data($data);

  my @args = (
    $self->release_id,
    $self->declaration || '',
    $data_string,
    $self->notes || '',
    $self->title || '',
    $self->content || '',
    $self->news_category_id || '',
    $self->priority || 0,
    $self->status || '',
    $self->news_done || 'N',
    $user->id || 0,
  );
  
  if ($id) {
    push @args, $id;
    $sth = $self->sql_update_item($id);
  }
  else {
    $sth = $self->sql_create_item();
  }

  $sth->execute(@args);
  $id = $sth->{mysql_insertid} unless $id;  

  ## Update many-to-many relationships
  ## Delete any existing links
  $sth = $self->sql_delete_species();
  $sth->execute($id);

  ## Add new ones in
  foreach my $sp (@$species) {
    $sth = $self->sql_add_species();
    $sth->execute($sp, $id);
  }

  return $id;

}

sub species_ids {
  my ($self, $id) = @_;
  $id = $self->id unless $id;

  my $sth = $self->sql_get_species();
  $sth->execute($id);

  my @ids;
  while (my @data = $sth->fetchrow_array()) {
    push @ids, $data[0];
  }

  return @ids;
}

sub fetch_news_items {
  my ($self, $criteria, $attr) = @_;

  my $where = '';
  my @args = ();
  
  foreach my $column ($self->columns) {
    next unless defined $criteria->{$column};
    $where .= " AND n.$column = ? ";
    push @args, $criteria->{$column};
  }
  
  if (ref($criteria->{'category'}) eq 'ARRAY') {
      my $string = join(' OR ', map { 'n.news_category_id = ?' } @{ $where->{'category'} });
      $where .= " AND ($string) " if $string;
      push @args, @{ $where->{'category'} };
  }

  if (exists $criteria->{'species'}) {
    my $sp = $criteria->{'species'};
    if (ref($sp) eq 'ARRAY') { 
      if (@$sp) {
        my $string = join(' OR ', map { $_ ? 'i.species_id = ?' : 'i.species_id IS NULL' } @$sp);
        $where .= " AND ($string) ";
        push @args, grep { $_ } @$sp;
      }
    } elsif ($sp) {
      $where .= ' AND i.species_id = ? ';
      push @args, $sp;
    } else {
      $where .= ' AND i.species_id IS NULL ';
    }
  }

  $attr->{order_by} ||= 'n.release_id DESC, c.priority ASC, n.priority DESC ';
  my $order = " ORDER BY $attr->{order_by} ";
  my $limit = $attr->{limit} ? " LIMIT $attr->{limit} " : '';

  my $sth = $self->sql_news_items($where, $order, $limit);
  $sth->execute(@args);
  
  my @results = $self->sth_to_objects($sth);
  return @results;
}



1;
