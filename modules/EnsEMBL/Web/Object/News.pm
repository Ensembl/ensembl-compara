package EnsEMBL::Web::Object::News;

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(escape);

use EnsEMBL::Web::Object;

our @ISA = qw(EnsEMBL::Web::Object);


#------------------- ACCESSOR FUNCTIONS -----------------------------

sub releases   { return $_[0]->Obj->{'releases'};   } ### a
sub all_cats   { return $_[0]->Obj->{'all_cats'};   }
sub all_spp   { return $_[0]->Obj->{'all_spp'};   }
sub valid_spp   { return $_[0]->Obj->{'valid_spp'};   }
sub current_spp   { return $_[0]->Obj->{'current_spp'};   }
sub valid_rels   { return $_[0]->Obj->{'valid_rels'};   }

sub generic_items { return $_[0]->Obj->{'generic_items'}; }
sub species_items { return $_[0]->Obj->{'species_items'}; }

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
