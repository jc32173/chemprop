import pandas as pd
import copy

def generate_deltaclass_pairs(y, relation=None, buffer=0, equals_only=False, indices_only=False, keep_all_data=False):
    """
    Function to generate pairs for DeltaClassifier model.

    # Print full output for manual testing:
    #>>> generate_deltaclass_pairs(df_data['y'], df_data['relation'], buffer=0, keep_all_data=True)
    >>> df_data = pd.DataFrame(data=[[1.2, '='],
    ...                              [2.1, '='],
    ...                              [2.4, '>'],
    ...                              [3.9, '<='],
    ...                              [0.7, '>='],
    ...                              [1.5, '<']],
    ...                        columns=['y', 'relation'])
    >>> generate_deltaclass_pairs(df_data['y'], df_data['relation'], buffer=0.5, indices_only=False)
        idx_x relation_x  Y_x  idx_y relation_y  Y_y  delta_Y  class_Y
    1       0          =  1.2      1          =  2.1      0.9     True
    2       0          =  1.2      2          >  2.4      1.2     True
    6       1          =  2.1      0          =  1.2     -0.9    False
    11      1          =  2.1      5          <  1.5     -0.6    False
    12      2          >  2.4      0          =  1.2     -1.2    False
    17      2          >  2.4      5          <  1.5     -0.9    False
    31      5          <  1.5      1          =  2.1      0.6     True
    32      5          <  1.5      2          >  2.4      0.9     True
    """

    if relation is None:
        print("No relation associated with y values, assuming all data is '='.")
        relation = ['=']*len(y)
        equals_only = True

    df = pd.DataFrame(zip(*[range(len(y)), relation, y]), columns=['idx', 'relation', 'Y'])

    if equals_only and not keep_all_data:
        df = df.loc[df['relation'] == '=']

    df_pairs = pd.merge(df, df, how='cross')

    df_pairs['delta_Y'] = df_pairs['Y_y'] - df_pairs['Y_x']

    # TODO: Don't keep separate copy of full dataframe
    if keep_all_data:
        df_all = copy.deepcopy(df_pairs)

        if equals_only:
            df_pairs = df_pairs.loc[(df_pairs['relation_x'] == '=') & (df_pairs['relation_y'] == '=')]

    # Remove pairs which fall within the buffer:
    if buffer > 0:
        df_pairs = df_pairs.loc[df_pairs['delta_Y'].abs() > buffer]

    # Prune invalid inequality data:
    if not equals_only:

        df_pairs = df_pairs.loc[~((df_pairs['relation_x'] == '=') & \
                                  (df_pairs['relation_y'].isin(['<', '<='])) & \
                                  (df_pairs['delta_Y'] > 0))]
        df_pairs = df_pairs.loc[~((df_pairs['relation_x'] == '=') & \
                                  (df_pairs['relation_y'].isin(['>', '>='])) & \
                                  (df_pairs['delta_Y'] < 0))]

        df_pairs = df_pairs.loc[~((df_pairs['relation_x'].isin(['<', '<='])) & \
                                  (df_pairs['relation_y'] == '=') & \
                                  (df_pairs['delta_Y'] < 0))]
        df_pairs = df_pairs.loc[~((df_pairs['relation_x'].isin(['>', '>='])) & \
                                  (df_pairs['relation_y'] == '=') & \
                                  (df_pairs['delta_Y'] > 0))]

        df_pairs = df_pairs.loc[~((df_pairs['relation_x'].isin(['>', '>='])) & \
                                  (df_pairs['relation_y'].isin(['<', '<='])) & \
                                  (df_pairs['delta_Y'] > 0))]
        df_pairs = df_pairs.loc[~((df_pairs['relation_x'].isin(['<', '<='])) & \
                                  (df_pairs['relation_y'].isin(['>', '>='])) & \
                                  (df_pairs['delta_Y'] < 0))]

        df_pairs = df_pairs.loc[~(df_pairs['relation_x'].isin(['>', '>=']) & \
                                  df_pairs['relation_y'].isin(['>', '>=']))]
        df_pairs = df_pairs.loc[~(df_pairs['relation_x'].isin(['<', '<=']) & \
                                  df_pairs['relation_y'].isin(['<', '<=']))]

    if indices_only:
        return df_pairs[['idx_x', 'idx_y']].to_numpy()

    y = (df_pairs['delta_Y'] > 0).rename('class_Y')

    if keep_all_data:
        df_pairs = df_all.join(y)
    else:
        df_pairs = df_pairs.join(y)

    return df_pairs
