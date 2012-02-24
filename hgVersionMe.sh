#!/bin/bash

# 02/18/2012
# me@kfring.com

# Auto Merge .hgtags
# Add this to your .hg/hgrc

#-----------------
# [merge-tools]
# merge-tags.executable = cat
# merge-tags.args = $local $other | sort -u >> $output

# [merge-patterns]
# .hgtags = merge-tags

#-----------------

# REPO VARS
REMOTE_REPO='https://bitbucket.org/{username}/{repoName}'
DEV_BRANCH='default'
REL_BRANCH='release'
DEP_BRANCH='deploy'

# SCRIPT VARS
NO_ARGS=0
E_OPTERROR=85
SPACER='        |'

hg_dirty() {
  hg status 2> /dev/null \
  | awk '$1 == "?" { print "?" } $1 != "?" { print "!" }' \
  | sort | uniq | head -c1
  # ? == untracked only
  # ! == modified tracked
}

hg_dirtyS() {
  S=$(hg_dirty)
  if [[ $S == "!" ]]; then
    echo "has uncommited changes"
  elif [[ $S == "?" ]]; then
    echo "has untracked files"
  elif [[ $S != "!" || $S != "?" ]]; then
    echo "is clean"
  fi
}

hg_changeset() {
  if [[ $2 ]]; then
    hg log -b $1 -r $2 -l 1 2> /dev/null | awk '/^changeset:/ { print $2 }'
  else
    hg log -b $1 -l 1 2> /dev/null | awk '/^changeset:/ { print $2 }'
  fi
}

hg_commitNum() {
  hg_changeset $1 $2 | awk -F: '{print $1}'
}

hg_tags() {
  if [[ $2 ]]; then
    hg log -b $1 -r $2 -l 1 2> /dev/null | awk '/^tag:/ { print $2 }'
  else
    hg log -b $1 -l 1 2> /dev/null | awk '/^tag:/ { print $2 }'
  fi
}

hg_latestTag() {
  # % hg log -b deploy -l 5
  # changeset:   32:ab1013f29923
  # branch:      deploy
  # parent:      1:6e84fee9e6ea
  # user:        l00pback0 <me@kfring.com>
  # date:        Tue Feb 21 21:23:00 2012 -0500
  # summary:     Added tag 0.0.31 for changeset 6e84fee9e6ea

  # changeset:   1:6e84fee9e6ea
  # branch:      deploy
  # tag:         0.0.31
  # user:        l00pback0
  # date:        Fri Feb 17 15:23:33 2012 -0500
  # summary:     Initial commit in deploy

  # Will only work on Release/Deploy branches
  # pass it a branch name
  array=($(hg log -b $1 2> /dev/null | awk '/^tag:/ { print $2 }'))
  if [[ ${array[0]} == "tip" ]]; then
    lastTag=${array[1]}
  else
    lastTag=${array[0]}
  fi
  echo $lastTag
}

hg_latestTags() {
  # Will only work on Release/Deploy branches
  # pass it a branch name.
  # This only gets the last Rev-1 tags if any...
  COM_REV=$(hg_commitNum $1) # Get the auto-commit Rev
  TAG_REV=$(($COM_REV-1))    # subtract one to get Rev with tags.
  hg log -b $1 -r $TAG_REV -l 1 2> /dev/null | awk '/^tag:/ { print $2 }'
}

hg_branch() {
  hg branch 2> /dev/null | awk '{ print $1 }'
}

hg_behindDev() {
  DEV_REV=$(hg_commitNum $DEV_BRANCH)
  QUERY_REV=$(hg_commitNum $1)
  DIFFERENCE=$(($DEV_REV-$QUERY_REV))
  echo $DIFFERENCE
}

hg_remoteTip() {
  hg id -i -r tip $REMOTE_REPO 2> /dev/null
}

hg_localTip() {
  hg id -i -r tip 2> /dev/null
}

hg_localRev() {
  hg id -inr tip 2> /dev/null | awk '{ print $2 }'
}

hg_remoteDifferent() { # Compare tips
  REMOTE_TIP=$(hg_remoteTip)
  LOCAL_TIP=$(hg_localTip)
  if [[ $REMOTE_TIP != $LOCAL_TIP ]]; then
    echo "(>O_O)> | INFO: The local repo and the remote repo do not match."
    echo "$SPACER" 'REMOTE: '$REMOTE_TIP
    echo "$SPACER" 'Local: '$LOCAL_TIP
  fi
}

hg_listBranch() {
  BRANCH_TAGS=$(hg_latestTags $1)
  BEHIND_DEF=$(hg_behindDev $1)
  echo "$SPACER" $1 'is' $BEHIND_DEF' behind '$DEV_BRANCH'. ('$(hg_commitNum $1)')'
  if [[ $BRANCH_TAGS != "" ]]; then
    echo "$SPACER" '--> tags:' $BRANCH_TAGS
  fi
  echo "$SPACER"
}

kirbySane() {
  # Are we in the DEV_BRANCH?
  CURRENT_BRANCH=$(hg_branch)
  if [[ $CURRENT_BRANCH != $DEV_BRANCH ]]; then
    echo "(>X_X)> | ERROR: You are not in the $DEV_BRANCH branch, Kirby will not run."
    echo -e "\n"
    exit $E_OPTERROR
  fi

  # Does the repo have pending commits
  # or unmodified files? Tell me.
  S=$(hg_dirty)
  if [[ $S = "!" ]]; then
    echo "(>X_X)> | ERROR: The local repo $(hg_dirtyS), Kirby will not run."
    echo -e "\n"
    exit $E_OPTERROR
  elif [[ $S = "?" ]]; then
    echo "(>O_O)> | INFO: The local repo $(hg_dirtyS)."
  #else
  #  echo "(>'_')> | The local repo $(hg_dirtyS)."
  fi
}

noargs() {
  echo "(>'_')> | Version Management. (Kirby)"
  echo "$SPACER Usage: `basename $0` options (-lrd)"
  echo "$SPACER  -l   Print status"
  echo "$SPACER  -r   Push dev to release"
  echo "$SPACER  -d   Push release to deploy"
  echo "$SPACER Rules:"
  echo "$SPACER  1)   You may NEVER merge into $DEP_BRANCH or $REL_BRANCH manually."
  echo "$SPACER  2)   You may do whatever you wish in $DEV_BRANCH."
  echo "$SPACER  3)   You may only ever run this script from $DEV_BRANCH."
  echo "$SPACER  4)   Never forget."
  exit $E_OPTERROR          # Exit and explain usage.
                            # Usage: scriptname -options
                            # Note: dash (-) necessary
}

kirbyGetVer() { # Pass it a branch.
  orgVer=`echo -e $(hg_latestTag $1) | awk '{ print $1 }'`
  echo $orgVer
  #sed 's/[^0-9.]*//g'
}

kirbyGrowVer() { # Pass two branches, second is branch we want to tag
  orgVer=$(kirbyGetVer $2)
  orgVerLessAlpha=`echo $orgVer | sed 's/[^0-9.]*//g'`
  if [[ "$orgVerLessAlpha" == "" ]]; then
    orgVerLessAlpha="0.0"
  fi
  c=( ${orgVerLessAlpha//./ } )  # replace points, split into array
  saneVer="${c[0]}.${c[1]}"
  commitNum=$(hg_localRev)

  echo "(>'_')> | Version Management. (Kirby)"
  echo "$SPACER Branch $2 is currently at:" $orgVer
  a=( ${saneVer//./ } )     # replace points, split into array
  b=( ${saneVer//./ } )     # replace points, split into array
  ((a[0]++))
  majVer="${a[0]}.${a[1]}"  # increment Major version
  ((b[1]++))
  minVer="${b[0]}.${b[1]}"  # increment Minor version

  read -p "$SPACER Increment Major Revision $orgVerLessAlpha -> $majVer? [y/n]:" -n 1
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
      newRev=$majVer
      # Add first letter of branch to major/minor Version:
      firstChr=`echo $2 | cut -b 1`
      read -p "$SPACER it looks like we're pushing to '$2', append '$firstChr'? [y/n]:" -n 1
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        newRev=$newRev$firstChr
      fi
  else
    read -p "$SPACER Increment Minor Revision $orgVerLessAlpha -> $minVer? [y/n]:" -n 1
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      newRev=$minVer
      # Add first letter of branch to major/minor Version:
      firstChr=`echo $2 | cut -b 1`
      read -p "$SPACER it looks like we're pushing to '$2', append '$firstChr'? [y/n]:" -n 1
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        newRev=$newRev$firstChr
      fi
    else
      newRev=""
    fi
  fi

  # Add revision Version Tag
  if [[ "$newRev" == "" ]]; then
    tempRev="0.0"
  else
    tempRev=$newRev
  fi
  newRevLessAlpha=`echo $tempRev | sed 's/[^0-9.]*//g'`
  read -p "$SPACER Would you like to also tag with: $newRevLessAlpha.$commitNum [y/n]:" -n 1
  echo
  devRev=""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
      if [[ "$newRev" == "" ]]; then
        devRev=$tempRev"."$commitNum
      else
        devRev=$newRevLessAlpha"."$commitNum
      fi
  fi

    # Make sure at least one tag is not empty.
    if [[ "$newRev" != "" || "$devRev" != "" ]]; then
      # Check to see if these Tags have ever been used:
      # TODO: Clean this up into one function
      if [[ "$newRev" != "" ]]; then
        # Test new rev
        tag_list=`hg tags | awk '{ print $1 }' | grep -E "^"$newRev"$" 2> /dev/null`
      fi
      if [[ "$devRev" != "" ]]; then
        # Test devRev
        tag_list2=`hg tags | awk '{ print $1 }' | grep -E "^"$devRev"$" 2> /dev/null`
      fi
      # Did we get a match at all? Then exit out.
      # TODO: Clean this up into one function
      if [[ $tag_list ]]; then
        echo "(>X_X)> | ERROR: Sorry, but the purposed tag already exist."
        echo "$SPACER" $newRev"=="$tag_list
        exit
      fi
      if [[ $tag_list2 ]]; then
        echo "(>X_X)> | ERROR: Sorry, but the purposed tag already exist."
        echo "$SPACER" $devRev"=="$tag_list2
        exit
      fi

      echo "$SPACER"
      echo "(>O_O)> | INFO: We are about to tag $2 with:" $newRev $devRev
      # Ask if they're sure.
      read -p "$SPACER Are you POSITIVE you want to do this? [y/n]:" -n 1
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Double Check their sureness
        read -p "$SPACER Are you HIV POSITIVE you want to do this? [y/n]:" -n 1
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          echo "(>'o')> | DOING MERGGY STUFF: RAWR RAWR RAWR"
          # DO MERGE
          hg update -c $2 # Update into branch
          hg merge -f $1  # Forcefully merge into branch
          hg commit -m "$1-->$2. Tags: $devRev $newRev"
          hg tag $devRev $newRev
          hg push -fb $2 $REMOTE_REPO
          hg update $DEV_BRANCH # Back to Developer Branch
          echo -e "\n"
          echo "(>'_')> | Version Management. (Kirby)"
          echo "$SPACER All done."
        else
          echo "(>O_O)> | Kirby was scared too, it's ok."
        fi
      echo
      fi
    else
      echo "(>X_X)> | ERROR: Nothing for Kirby to do."
    fi
}

# BEEF
if [ $# -eq "$NO_ARGS" ]    # Script invoked with no command-line args?
then
  noargs
fi

kirbySane
while getopts ":lrd" Option
  do
    case $Option in
      l )
          hg_listBranch $DEV_BRANCH
          hg_listBranch $REL_BRANCH
          hg_listBranch $DEP_BRANCH
          #hg_remoteDifferent     # MEH!
      ;;
      r )
          # Merge default to release and add version tags.
          kirbyGrowVer $DEV_BRANCH $REL_BRANCH
      ;;
      d )
          # Merge release to deploy and add version tags.
          kirbyGrowVer $REL_BRANCH $DEP_BRANCH
      ;;
      * ) echo "Unimplemented option chosen.";;   # Default.
    esac
    echo -e "\n"
  done

shift $(($OPTIND - 1))
#  Decrements the argument pointer so it points to next argument.
#  $1 now references the first non-option item supplied on the command-line
#+ if one exists.
exit $?
