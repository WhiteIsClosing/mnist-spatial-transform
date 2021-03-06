-- code based on https://github.com/torch/demos/blob/master/train-a-digit-classifier/dataset-mnist.lua

require 'torch'
require 'paths'
require "lfs"

mnist = {}

local dim = {}
dim.channels = 1
dim.width = 60
dim.height = 60
dim.classes = 10

function mnist.dim()
  return dim
end

-- mnist.path_remote = 'https://s3.amazonaws.com/torch7/data/mnist.t7.tgz'
mnist.path_dataset = 'distortedmnist.t7'
mnist.path_trainset = paths.concat(mnist.path_dataset, 'train_32x32.t7')
mnist.path_testset = paths.concat(mnist.path_dataset, 'test_32x32.t7')

function mnist.download()
  if not paths.filep(mnist.path_trainset) or not paths.filep(mnist.path_testset) then
    print('distortedmnist.download')
    local matio = require 'matio'
    -- local train = matio.load('Distorted_train.mat', 'train')
    lfs.mkdir(mnist.path_dataset)
    local train = matio.load('dis_train.mat', 'train')
    print('train loaded from matlab')
    torch.save(mnist.path_trainset, train, 'ascii')
    print('train loaded saved to ', mnist.path_trainset)

    local test = matio.load('dis_test.mat', 'test')
    print('test loaded from matlab')
    torch.save(mnist.path_testset, test, 'ascii')
    print('test loaded saved to ', mnist.path_testset)
  end
end

function mnist.loadTrainSet(maxLoad, geometry)
  mnist.download()
  return mnist.loadDataset(mnist.path_trainset, maxLoad, geometry)
end

function mnist.loadTestSet(maxLoad, geometry)
  mnist.download()
  return mnist.loadDataset(mnist.path_testset, maxLoad, geometry)
end

function mnist.loadDataset(fileName, maxLoad)
  mnist.download()

  local f = torch.load(fileName, 'ascii')
  local data = f.data:type(torch.getdefaulttensortype())
  -- local labels = f.labels
  local labels = f.label

  local nExample = f.data:size(1)
  if maxLoad and maxLoad > 0 and maxLoad < nExample then
    nExample = maxLoad
    print('<mnist> loading only ' .. nExample .. ' examples')
  end
  data = data[{{1,nExample},{},{},{}}]
  labels = labels[{{1,nExample}}]
  print('<mnist> done')

  local dataset = {}
  dataset.data = data
  dataset.labels = labels
  dataset.label = labels

  function dataset:normalize(mean_, std_)
    -- local mean = mean_ or data:view(data:size(1), -1):mean(1)
    -- local std = std_ or data:view(data:size(1), -1):std(1, true)
    -- -- print("data", data)
    -- print("data:size()", data:size())
    -- print("data:size(1)", data:size(1))
    -- for i=1,data:size(1) do
    --   data[i]:add(-mean[1][i])
    --   if std[1][i] > 0 then
    --     tensor:select(2, i):mul(1/std[1][i])
    --   end
    -- end
    -- return mean, std
    local norm_kernel = image.gaussian1D(7)
    local norm = nn.SpatialContrastiveNormalization(1,norm_kernel)
    local batch = 200 -- Can be reduced if you experience memory issues
    local dataset_size = data:size(1)
    for i=1,dataset_size,batch do
      local local_batch = math.min(dataset_size,i+batch) - i
      local normalized_images = norm:forward(data:narrow(1,i,local_batch))
      data:narrow(1,i,local_batch):copy(normalized_images)
    end
  end

  function dataset:normalizeGlobal(mean_, std_)
    local std = std_ or data:std()
    local mean = mean_ or data:mean()
    data:add(-mean)
    data:mul(1/std)
    return mean, std
  end

  function dataset:size()
    return nExample
  end

  local labelvector = torch.zeros(10)

  setmetatable(dataset, {__index = function(self, index)
      local input = self.data[index]
      local label = self.labels[index]
      -- local class = self.labels[index]
      -- local label = labelvector:zero()
      -- label[class] = 1
      local example = {input, label}
      return example
    end})

  return dataset
end

-- Return the module
return mnist

-- local pl = (require 'pl.import_into')()

-- require 'torch'
-- require 'image'

-- torch.setdefaulttensortype('torch.FloatTensor')

-- local CHANNELS = 3
-- local WIDTH = 48
-- local dataset = {}

-- -- Private function declaration
-- local generate_dataset
-- local prune_dataset

-- -- These paths should not be changed
-- dataset.path_remote_train = "http://benchmark.ini.rub.de/Dataset/GTSRB_Final_Training_Images.zip"
-- dataset.path_remote_test = "http://benchmark.ini.rub.de/Dataset/GTSRB_Final_Test_Images.zip"
-- dataset.path_remote_test_gt = "http://benchmark.ini.rub.de/Dataset/GTSRB_Final_Test_GT.zip"

-- dataset.train_dataset_bin = "train_datasetmnist.bin"
-- dataset.validation_dataset_bin = "validation_datasetmnist.bin"
-- dataset.test_dataset_bin = "test_datasetmnist.bin"


-- -- This function will download the dataset in the './GTSRB' temp folder, and generate
-- -- binary files containing the dataset as torch tensors.
-- function dataset.download_generate_bin()
--   if not pl.path.isfile(dataset.train_dataset_bin) or
--      not pl.path.isfile(dataset.validation_dataset_bin) or
--      not pl.path.isfile(dataset.test_dataset_bin) then

--      if not pl.path.isdir('GTSRB') then
--       local tar_train = paths.basename(dataset.path_remote_train)
--       local tar_test = paths.basename(dataset.path_remote_test)
--       local tar_test_gt = paths.basename(dataset.path_remote_test_gt)

--       print('Downloading dataset...')
--       os.execute('wget ' .. dataset.path_remote_train .. '; ' ..
--                  'unzip ' .. tar_train .. '; '..
--                  'rm ' .. tar_train)
--       os.execute('wget ' .. dataset.path_remote_test .. '; ' ..
--                  'unzip ' .. tar_test .. '; '..
--                  'rm ' .. tar_test .. '; ' ..
--                  'mkdir GTSRB/Final_Test/Images/final_test; ' ..
--                  -- too many arguments for a plain mv...
--                  [[find GTSRB/Final_Test/Images/ -maxdepth 1 -name '*.ppm' -exec sh -c 'mv "$@" "$0"' GTSRB/Final_Test/Images/final_test/ {} +;]] ..
--                  'rm GTSRB/Final_Test/Images/GT-final_test.test.csv')
--       os.execute('wget ' .. dataset.path_remote_test_gt .. '; ' ..
--                  'unzip ' .. tar_test_gt .. '; '..
--                  'rm ' .. tar_test_gt .. '; ' ..
--                  'mv GT-final_test.csv GTSRB/Final_Test/Images/final_test/GT-final_test.csv')
--     end

--     print('Generating bin of the dataset')
--     local train_set, validation_set = generate_dataset('GTSRB/Final_Training/Images', true)
--     torch.save(dataset.train_dataset_bin, train_set)
--     train_set = nil
--     torch.save(dataset.validation_dataset_bin, validation_set)
--     validation_set = nil
--     collectgarbage()
--     local test_set = generate_dataset('GTSRB/Final_Test/Images')
--     torch.save(dataset.test_dataset_bin, test_set)
--     test_set = nil
--     collectgarbage()

--     if paths.dirp('GTSRB') then
--       os.execute('rm -r GTSRB')
--     end
--   end
-- end

-- -------------------------------------------------
-- -- Main Interface
-- -------------------------------------------------

-- -- Returns the train dataset
-- -- nbr_examples is optional and allows to get only a subset of the training samples
-- -- use validation allows to return both a test and validation set (split is done
-- -- the same way as the paper from Sermanet adnd LeCun)
-- -- Warning: if the number of examples is not limited, the dataset is ordered by class
-- -- If the number of examples is limited, the subset will be shuffled.
-- function dataset.get_train_dataset(nbr_examples, use_validation)
--   dataset.download_generate_bin()
--   local train_dataset = torch.load(dataset.train_dataset_bin)
--   local validation_dataset = torch.load(dataset.validation_dataset_bin)

--   if not use_validation then
--     -- Merge both train and validation set to have the full train set
--     local full_train_dataset = {}
--     -- Create the full dataset with the proper size
--     local data_size = train_dataset.data:size()
--     local label_size = train_dataset.label:size()
--     local nbr_train_examples = train_dataset.data:size(1)
--     local nbr_val_examples = validation_dataset.data:size(1)
--     data_size[1] = nbr_train_examples + nbr_val_examples
--     label_size[1] = nbr_train_examples + nbr_val_examples
--     full_train_dataset.data = torch.Tensor(data_size)
--     full_train_dataset.label = torch.Tensor(label_size)
--     -- Copy the data in the full dataset
--     full_train_dataset.data:narrow(1,
--                                   1,nbr_train_examples):copy(
--                                   train_dataset.data)
--     full_train_dataset.data:narrow(1,
--                                   nbr_train_examples+1,
--                                   nbr_val_examples):copy(
--                                   validation_dataset.data)
--     full_train_dataset.label:narrow(1,
--                                   1,nbr_train_examples):copy(
--                                   train_dataset.label)
--     full_train_dataset.label:narrow(1,
--                                   nbr_train_examples+1,
--                                   nbr_val_examples):copy(
--                                   validation_dataset.label)
--     validation_dataset = nil
--     train_dataset = full_train_dataset
--   end


--   -- Limit the number of samples if required by the user
--   if nbr_examples and nbr_examples ~= -1 then
--     train_dataset = prune_dataset(train_dataset, nbr_examples)
--   end

--   return train_dataset, validation_dataset
-- end

-- -- Returns the test dataset
-- -- nbr_examples is optional and allows to get only a subset of the testing samples
-- -- Warning: if the number of examples is not limited, the dataset is ordered by class
-- -- If the number of examples is limited, the subset will be shuffled.
-- function dataset.get_test_dataset(nbr_examples)
--   dataset.download_generate_bin()
--   local test_dataset = torch.load(dataset.test_dataset_bin)

--   -- Limit the number of samples if required by the user
--   if nbr_examples and nbr_examples ~= -1 then
--     test_dataset = prune_dataset(test_dataset, nbr_examples)
--   end
--   return test_dataset
-- end

-- -- Normalize the given dataset
-- -- You can specify the mean and std values, otherwise, they are computed on the given dataset
-- -- Return the mean and std values
-- function dataset.normalize_global(dataset, mean, std)
--   local std = std or dataset.data:std()
--   local mean = mean or dataset.data:mean()
--   dataset.data:add(-mean)
--   dataset.data:div(std)
--   return mean, std
-- end

-- -- Locally normalize the dataset
-- function dataset.normalize_local(dataset)
--   require 'image'
--   local norm_kernel = image.gaussian1D(7)
--   local norm = nn.SpatialContrastiveNormalization(CHANNELS,norm_kernel)
--   local batch = 200 -- Can be reduced if you experience memory issues
--   local dataset_size = dataset.data:size(1)
--   for i=1,dataset_size,batch do
--     local local_batch = math.min(dataset_size,i+batch) - i
--     local normalized_images = norm:forward(dataset.data:narrow(1,i,local_batch))
--     dataset.data:narrow(1,i,local_batch):copy(normalized_images)
--   end
-- end

-- -------------------------------------------------
-- -- Private function
-- -------------------------------------------------

-- prune_dataset = function(dataset, nbr_examples)
--   -- Limit the number of samples if required by the user
--   assert(nbr_examples and nbr_examples > 1 and nbr_examples < dataset.data:size(1),
--          'Invalid number of examples required, not within dataset range.')

--   local randperm = torch.randperm(dataset.data:size(1))
--   local subset_data = torch.Tensor(nbr_examples, CHANNELS, WIDTH, WIDTH)
--   local subset_label = torch.Tensor(nbr_examples, 1)
--   for i=1,nbr_examples do
--     subset_data[i]:copy(dataset.data[randperm[i]])
--     subset_label[i]:copy(dataset.label[randperm[i]])
--   end
--   dataset.data = subset_data
--   dataset.label = subset_label
--   collectgarbage()

--   return dataset
-- end

-- -- This will generate a dataset as torch tensor from a directory of images
-- -- parent_path is a string of the path containing all the images
-- -- use validation allows to generate a validation set
-- generate_dataset = function(parent_path, use_validation)
--   assert(parent_path, "A parent path is needed to generate the dataset")

--   local main_dataset = {}
--   main_dataset.nbr_elements = 0

--   -- This will only be used if use_validation is true
--   local validation_dataset = {}
--   validation_dataset.nbr_elements = 0

--   local images_directories = pl.dir.getdirectories(parent_path)
--   table.sort(images_directories)

--   for image_directory_id, image_directory in ipairs(images_directories) do
--     local csv_file_name = 'GT-' .. pl.path.basename(image_directory) .. '.csv'
--     local csv_file_path = pl.path.join(image_directory, csv_file_name)

--     local csv_content = pl.data.read(csv_file_path)

--     local filename_index = csv_content.fieldnames:index('Filename')
--     local class_id_index = csv_content.fieldnames:index('ClassId')

--     local track_for_validation
--     if use_validation then
--       -- Count number of tracks for this class
--       local max_track_nbr = 0
--       for image_index, image_metadata in ipairs(csv_content) do
--         local track_nbr = tonumber(pl.utils.split(image_metadata[filename_index], '_')[1])
--         if track_nbr > max_track_nbr then
--           max_track_nbr = track_nbr
--         end
--       end

--       -- Select one random track for validation
--       track_for_validation = math.floor(math.random()*max_track_nbr) + 1
--     else
--       track_for_validation = -1
--     end

--     for image_index, image_metadata in ipairs(csv_content) do
--       local track_nbr = tonumber(pl.utils.split(image_metadata[filename_index], '_')[1])
--       local image_path = pl.path.join(image_directory, image_metadata[filename_index])
--       local image_data = image.load(image_path)

--       -- We do no transformation but a rescaling so all the images have the same size
--       image_data = image.scale(image_data, WIDTH, WIDTH)

--       local label = torch.Tensor{image_metadata[class_id_index]+1}

--       if use_validation and track_nbr == track_for_validation then
--         validation_dataset.nbr_elements = validation_dataset.nbr_elements + 1
--         validation_dataset[validation_dataset.nbr_elements] = {image_data, label}
--       else
--         main_dataset.nbr_elements = main_dataset.nbr_elements + 1
--         main_dataset[main_dataset.nbr_elements] = {image_data, label}
--       end

--       if image_index % 50 == 0 then
--         collectgarbage()
--       end
--     end
--   end

--   -- Store everything as proper torch Tensor now that we know the total size
--   local main_data = torch.Tensor(main_dataset.nbr_elements, CHANNELS, WIDTH, WIDTH)
--   local main_label = torch.Tensor(main_dataset.nbr_elements, 1)
--   for i,pair in ipairs(main_dataset) do
--     main_data[i]:copy(main_dataset[i][1])
--     main_label[i]:copy(main_dataset[i][2])
--   end
--   main_dataset = {}
--   main_dataset.data = main_data
--   main_dataset.label = main_label

--   if use_validation then
--     -- Store everything as proper torch Tensor now that we know the total size
--     local validation_data = torch.Tensor(validation_dataset.nbr_elements, CHANNELS, WIDTH, WIDTH)
--     local validation_label = torch.Tensor(validation_dataset.nbr_elements, 1)
--     for i,pair in ipairs(validation_dataset) do
--       validation_data[i]:copy(validation_dataset[i][1])
--       validation_label[i]:copy(validation_dataset[i][2])
--     end
--     validation_dataset = {}
--     validation_dataset.data = validation_data
--     validation_dataset.label = validation_label

--     return main_dataset, validation_dataset
--   else
--     return main_dataset
--   end
-- end

-- -- Return the module
-- return dataset
