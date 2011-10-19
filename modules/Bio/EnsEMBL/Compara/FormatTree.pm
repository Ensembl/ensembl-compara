=head1 LICENSE

  Copyright (c) 1999-2010 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

package Bio::EnsEMBL::Compara::FormatTree;

use strict;
use warnings;
use Data::Dumper;
use Carp;

# Grammar to parse $fmt
sub _tokenize {
  my ($self) = @_;
  eval { require Parse::RecDescent };
  if ($@) {
    die 'You need Parse::RecDescent installed to role-your-own tree format\n'
  }
  my $parser = Parse::RecDescent->new(q(
                                   {my @tokens; push @tokens,{}}
                                    hyphen      : "-"
                                    has_parent  : "^"
                                    { $tokens[-1]->{has_parent} = 1 }
                                    or          : "|"
                                    character   : /[\w\.\s:\|]+/i
                                    literal     : character
                                        { $tokens[-1]->{literal} = $item{character} }
                                    Letter_code : "n" | "c" | "d" | "t" | "l" | "h" | "s" | "p" | "m" | "g" | "i" | "e" | "o" | "x" | "S"
                                    preliteral  : character
                                        { $tokens[-1]->{ preliteral } = $item{character} }
                                    postliteral : character
                                       { $tokens[-1]->{ postliteral } = $item{character} }
                                    In_leaf     : hyphen Letter_code
                                      {
                                         $tokens[-1]->{main} = $item{Letter_code}
                                      }
                                    In_internal : Letter_code hyphen
                                      {
                                         $tokens[-1]->{main} = $item{Letter_code}
                                      }
                                    Format      : /^/ Entry(s) /$/ {\@tokens}
                                    Entry       : (Token_or_literal)(s)
                                    Token_or_literal : Token
                                    Token_or_literal : literal
                                      {
                                         push @tokens, {}
                                      }

                                    Token       : "%{" (has_parent)(?) ('"' <skip: ''> preliteral '"')(?) Condition ('"' <skip: ''> postliteral '"')(?) "}"
                                      {
                                         push @tokens, {}
                                      }

                                    Condition   : Code ( or Letter_code )(s?)
                                      {
                                        if (scalar @{$item[2]}) {
                                            $tokens[-1]->{alternatives} = join "", @{$item[2]}
                                        }
                                      }
                                    Code        : In_leaf
                                      {
                                         $tokens[-1]->{place} = "Leaf";
                                      }
                                    Code        : In_internal
                                      {
                                         $tokens[-1]->{place} = "Internal";
                                      }
                                    Code        : Letter_code
                                      {
                                         $tokens[-1]->{place} = "Both";
                                         $tokens[-1]->{main} = $item{Letter_code}
                                      }
));
  my $fmt = $self->{fmt};
  my $tokens = $parser->Format($fmt);
  croak "Format $fmt is not valid\n" unless (defined $tokens);
  my @tokens = grep {scalar keys %{$_} > 0} @$tokens;    ## Hacky... but shouldn't be needed anymore (just a pop)
  $self->{tokens} = [@tokens];
}

## Callbacks

my %callbacks = ();

## maybe we can use AUTOLOAD to populate most of these?

my $name_cb = sub {
  my ($self) = @_;
  return sprintf ("%s",$self->{tree}->name || '');
};

my $distance_to_parent_cb = sub {
  my ($self) = @_;
  my $dtp = $self->{tree}->distance_to_parent();
  if ($dtp =~ /^\d+\.\d+$/) {
    return sprintf ("%1.4f", $self->{tree}->distance_to_parent);
  } else {
    return sprintf ("%d", $self->{tree}->distance_to_parent);
  }
};

my $genbank_common_name = sub {
  my ($self) = @_;
  my $common = uc($self->{tree}->get_tagvalue('genbank common name'));
  $common =~ s/\,//g;
  $common =~ s/\ /\./g;
  $common =~ s/\'//g;
  return $common || undef;
};

my $ensembl_common_name = sub {
  my ($self) = @_;
  my $common = uc($self->{tree}->get_tagvalue('ensembl common name'));
  $common =~ s/\,//g;
  $common =~ s/\ /\./g;
  $common =~ s/\'//g;
  return $common;
};

my $ensembl_timetree_mya_cb = sub {
  my ($self) = @_;
  my $str = sprintf ("%s", $self->{tree}->get_tagvalue('ensembl timetree mya'));
  return $str eq "" ? undef : $str;
};

my $gdb_id_cb = sub {
  my ($self) = @_;
  my $gdb_id;
  eval {
    $gdb_id = $self->{tree}->adaptor->db->get_GenomeDBAdaptor->fetch_by_taxon_id($self->{tree}->taxon_id)->dbID;
  };
  return $gdb_id;
};

my $node_id_cb = sub {  ## only if we are in a leaf? ... if ($self->{tree}->is_leaf);
  my ($self) = @_;
  return sprintf("%s", $self->{tree}->node_id);
};

my $label_cb = sub { ## only if we are in a leaf? ... if ($self->{tree}->is_leaf);
  my ($self) = @_;
  my $display_label = $self->{tree}->gene_member->display_label;
  return $display_label;
};

my $sp_short_name_cb = sub {
  my ($self) = @_;
  my $sp;
  eval {
    $sp = $self->{tree}->genome_db->short_name
  };
  return $sp;
};

my $stable_id_cb = sub {  ## only if we are in a leaf?
  my ($self) = @_;
  return $self->{tree}->gene_member->stable_id;
};

my $prot_id_cb = sub {
  my ($self) = @_;
  my $prot_member;
  eval {$prot_member = $self->{tree}->get_canonical_peptide_Member->stable_id};
  return $prot_member;
};

my $member_id_cb = sub {
  my ($self) = @_;
  return sprintf ("%s",$self->{tree}->member_id);
};

my $taxon_id_cb = sub {
  my ($self) = @_;
  my $taxon_id;
  eval { $taxon_id = $self->{tree}->taxon_id };
  return $taxon_id;
#  return sprintf ("%s", $self->{tree}->taxon_id);
};

my $sp_name_cb = sub {
  my ($self) = @_;
  my $species_name;
  if ($self->{tree}->isa('Bio::EnsEMBL::Compara::GeneTreeMember')) {
    $species_name = $self->{tree}->genome_db->name;
    $species_name =~ s/\ /\_/g;
    return $species_name
  }
  return undef;
};

%callbacks = (
	      'n' => $name_cb,
	      'c' => $genbank_common_name,
	      'e' => $ensembl_common_name,
	      'd' => $distance_to_parent_cb,
	      't' => $ensembl_timetree_mya_cb,
	      'g' => $gdb_id_cb,
	      'o' => $node_id_cb,
	      'l' => $label_cb,
	      's' => $sp_short_name_cb,
	      'i' => $stable_id_cb,
	      'p' => $prot_id_cb,
	      'm' => $member_id_cb,
	      'x' => $taxon_id_cb,
	      'S' => $sp_name_cb,
#	      'E' =>  ## Implement the "Empty" option
	     );


# Maybe leaves and internal nodes should be formatted different?
my %cache;
sub new {
  my ($class,$fmt) = @_;
  $fmt = "%{n}" unless (defined $fmt); # "full" by default
  if (defined $cache{$fmt}) {
    return $cache{$fmt};
  }
  my $obj = bless ({
		    'fmt' => $fmt,
		    'tokens' => [],
		    'callbacks' => {%callbacks},
		   }, $class);
  eval {
    $obj->_tokenize();
  };
  if ($@) {
    die $@ if ($@ =~ /Parse::RecDescent/);
    die "Bad format : $fmt\n";
  }
  $cache{$fmt} = $obj;
  return $obj;
}

sub format_newick {
  my ($self, $tree) = @_;
  return $self->_internal_format_newick($tree);
}

sub _internal_format_newick {
  my ($self, $tree) = @_;

  my $newick = "";
  if ($tree->get_child_count()>0) {
    $newick .= "(";
    my $first_child = 1;
    for my $child (@{$tree->sorted_children}) {
      $newick .= "," unless ($first_child);
      $newick .= $self->_internal_format_newick($child);
      $first_child = 0;
    }
    $newick .= ")";
  }

  my $header = "";
  $self->{tree} = $tree;
  for my $token (@{$self->{tokens}}) {
    if (defined $token->{literal}) {
      $header .= $token->{literal}
    } elsif (($token->{place} eq "Leaf") && ($tree->is_leaf) ||
	     ($token->{place} eq "Internal") && (! $tree->is_leaf) ||
	     ($token->{place} eq "Both")) {
      next if (defined $token->{has_parent} && $token->{has_parent} == 1 && !$tree->parent);
      for my $item (split //,$token->{main}.$token->{alternatives}x!!$token->{alternatives}) {  ## For "main" and "alternatives"
	my $itemstr = $self->{callbacks}{$item}->($self);
#	print STDERR "ITEMSTR:$itemstr\n";exit;
	if (defined $itemstr) {
	  $header .= $token->{preliteral}x!!$token->{preliteral}.$itemstr.$token->{postliteral}x!!$token->{postliteral};
	  last;
	}
      }
    }
  }
#  $header .= ":".$self->{callbacks}{d}->($self);
  return $newick.$header;
}


1;

### NEED TO BE UPDATED

# ++ A "format" is a regular string containing string literals and "tokens". Tokens are:
# %{n} --> then "name" of the node ($self->name)
# %{c} --> the common name ($self->get_tagvalue('genbank common name'))
# %{d} --> gdb_id ($self->adaptor->db->get_GenomeDBAdaptor->fetch_by_taxon_id($self->taxon_id)->dbID)
# %{t} --> timetree ($self->get_tagvalue('ensembl timetree mya')
# %{l} --> display_label ($self->gene_member->display_label)
# %{h} --> genome short name ($self->genome_db->short_name)
# %{s} --> stable_id ($self->gene_member->stable_id)
# %{p} --> peptide Member ($self->get_canonical_peptide_Member->stable_id)
# %{t} --> taxon_id ($self->taxon_id)
# %{m} --> member_id ($self->member_id)
# %{g} --> genome_db name ($self->genome_db->name)
# %{i} --> node_id ($self->node_id)
# %{e} --> nothing (useful to include only regular characters, see below)

# ++ These "tokens" can be modified using the following rules:

# + Apply tokens only to leaves or internal nodes:
# %{n}  --> The token applies to nodes and leaves
# %{-n} --> The token applies only to leaves
# %{n-} --> The token applies only to internal nodes

# + Tokens can be applied conditionally:
# %{p:n} --> Give the "peptide_member_stable_id" or (if it is undefined), the name
# %{-p:n} --> Same as below, but only for leaves
# %{n:-p} --> Give the name, but for leaves give the peptide_id.

# + string literals can be inserted outside or inside tokens (the meaning is slightly different):
# _%{n} --> Put an underscore and the name.
# %{_n} --> Put an underscore and the name only if name is defined.
# %{_-e} --> Put an underscore only if you are in a leaf.

# + hyphens and closing brackets are not allowed (we can define a way to scape them).

# ++ Equivalences with existing formats:

# "full" --> ‘%{n}’

# "full_common" --> '%{n}%{ -c}%{.-d}{_t-}' -- Reads: Print the name of the node, if you are in a leaf and its "common_name" is defined print a space and the "common_name". Then, if you are in a leaf and the "gdb_id" is defined, print a dot and the "gdb_id", print an underscore and the "ensembl timetree mya".

# "int_node_id" --> '%{-n}%{-I}'

# display_label_composite --> '%{-l_}%{n}%{_-e}%{-h}' -- Reads: If you are in a leaf and the "display label" is defined, print it followed by an underscore. Print the "name". If you are in a leaf node, print an underscore and the "genome short name".

# "gene_stable_id_composite" --> '%{-s_}%{n}{_e}%{-h}'

# "full_web" --> '%{n:-p}%{_-e}%{-h}%{_-e}%{-l} -- Reads: Print the name or the stable id of the peptide member if it you are in a leaf and it is defined. Then print an underscore if you are in a leaf. Print the genome short name if you are in a leaf. Print an underscore if you are in a leaf. Print the display label if you are in a leaf.

# Etc...


# M;

# PS: The specification of the format in EBNF could be something like this:

# Format = “'” { string_literal | Token } “'” .
# Token = “%{“ [string_literal] Code [ “:” Code ] [string_literal] “}” .
# Code = [ “-”  ] Letter_code [ “-” ]
# Letter_code = [ “n“ | “c” | “d” | “t” | “l” | “h” | “s” | “p” | “t” | “m” | “g” | “i” | “e” ] .
