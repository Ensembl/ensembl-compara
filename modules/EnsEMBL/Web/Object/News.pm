package EnsEMBL::Web::Object::News;

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(escape);

use EnsEMBL::Web::Object;
use EnsEMBL::Web::Factory::News;

our @ISA = qw(EnsEMBL::Web::Object);

#------------------- ACCESSOR FUNCTIONS -----------------------------

sub release_id  { return $_[0]->Obj->{'release_id'};   }
sub releases    { return $_[0]->Obj->{'releases'};   }
sub all_cats    { return $_[0]->Obj->{'categories'};   }
sub all_spp     { return $_[0]->Obj->{'species'};   }

sub sp_array {
  my $self = shift;
  ## sort out array of chosen species
  my $all_spp = $self->all_spp;
  my @sp_array = ();
  if ($self->param('species')) {
    @sp_array = ($self->param('species'));
  }
  else { ## create based on name of directory
    my $sp_dir = $self->species;
    if ($sp_dir eq 'Multi') { ## make array of all species ids
      @sp_array = sort {$a <=> $b} keys %$all_spp;
    }
    else { ## look up species id from directory name
      my %rev_hash = reverse %$all_spp;
      @sp_array = ($rev_hash{$sp_dir});
    }
  }
  return \@sp_array; 
}

#------------------- DATABASE QUERIES -------------------------------

sub valid_spp   { 
  my $self = shift;
  my $adaptor = $self->EnsEMBL::Web::Factory::News::news_adaptor;
  my $species = $adaptor->fetch_species($self->release_id); 
  return $species;  
}

sub current_spp   { 
  my $self = shift;
  my $adaptor = $self->EnsEMBL::Web::Factory::News::news_adaptor;
  my $species = $adaptor->fetch_species($self->species_defs->ENSEMBL_VERSION); 
  return $species;  
}

sub valid_rels   { 
  my $self = shift;
  my $adaptor = $self->EnsEMBL::Web::Factory::News::news_adaptor;
  my $releases = [];
  my @sp_array = @{$self->sp_array};
  if (scalar(@sp_array) == 1 && $sp_array[0]) { ## single species
    $releases = $self->news_adaptor->fetch_releases({'species'=>$sp_array[0]});
  }
  else { ## in multi-species mode, all releases are valid
    $releases = $adaptor->fetch_releases;
  }
  return $releases;  
}

sub generic_items { 
  my $self = shift;
  my $adaptor = $self->EnsEMBL::Web::Factory::News::news_adaptor;
  my $release_id = $self->release_id;
  my %where = ();

  ## set up query criteria
  if ($self->param('news_cat_id')) {
    $where{'category'} = $self->param('news_cat_id');
  }
  if ($release_id) {
    $where{'release'} = $release_id;
  }

  my $items = $adaptor->fetch_news_items(\%where, 1);
  return $items;
}

sub species_items { 
  my $self = shift;
  my $adaptor = $self->EnsEMBL::Web::Factory::News::news_adaptor;
  my $release_id = $self->release_id;
  my %where = ();

  ## set up query criteria
  if ($self->param('news_cat_id')) {
    $where{'category'} = $self->param('news_cat_id');
  }
  if ($release_id) {
    $where{'release'} = $release_id;
  }
  my @sp_array = @{$self->sp_array};
  if (scalar(@sp_array) == 1 && $sp_array[0]) { ## single species
    $where{'species'} = $sp_array[0];
  }

  my $items = $adaptor->fetch_news_items(\%where);
  return $items;
}

sub sort_items {
### Complex custom sort for news stories. Will weed out duplicate news items if passed
### a set of concatenated lists (see arguments), and output in a variety of orders
### Arguments (1) an E::W::Proxy::Object(News) 
### (2) a reference to an array of hashes (news items) - this can be one or more arrays that
### have been concatenated
### (3) string : current accepted value is 'headline', which sorts only by priority; the 
### default is to sort by release, category, priority, then number of species
### Returns a reference to an array of hashes (news items)
 
  my ($self, $items, $order) = @_;

  ## in case we are merging lists, remove duplicates
  my (@unique, %tally);
  foreach my $item (@$items) {
    my $id = $item->{'news_item_id'};
    $tally{$id}++;
    unless ($tally{$id} > 1) {
      push @unique, $item;
    }
  }

  ## define sort
  my ($sorted, $sub);
  if ($order eq 'headline') {
    $sub = sub {return $b->{"priority"} <=> $a->{"priority"}};
  }
  else { ## default sort
    $sub = sub {
              return
              $b->{"release_id"} <=> $a->{"release_id"}
                ||
              $b->{"cat_order"} <=> $a->{"cat_order"}
                ||
              $b->{"priority"} <=> $a->{"priority"}
                ||
              $b->{"sp_count"} <=> $a->{"sp_count"}
            };
  }
 
  ## sort unique items
  @$sorted = sort $sub @unique;
  return $sorted;
}


1;
