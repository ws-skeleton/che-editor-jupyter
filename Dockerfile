FROM jupyter/minimal-notebook:6d2a05346196

# Switch to the root user so we can install additional packages.

USER root

# Install additional libraries required by Python packages which are in
# the minimal base image. Also install 'rsync' so the 'oc rsync' command
# can be used to copy files into the running container.

RUN apt-get update && \
    apt-get install -y --no-install-recommends rsync && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add labels so OpenShift recognises this as an S2I builder image.

LABEL io.k8s.description="S2I builder for Jupyter (minimal-notebook)." \
      io.k8s.display-name="Jupyter (minimal-notebook)" \
      io.openshift.expose-services="8888:http" \
      io.openshift.tags="builder,python,jupyter" \
      io.openshift.s2i.scripts-url="image:///opt/app-root/s2i/bin"

# Copy in S2I builder scripts for installing Python packages and copying
# in of notebooks and data files.

COPY s2i /opt/app-root/s2i

# Adjust permissions on home directory so writable by group root.

RUN chgrp -Rf root /home/$NB_USER && chmod -Rf g+w /home/$NB_USER

# Adjust permissions on /etc/passwd so writable by group root.

RUN chmod g+w /etc/passwd

# Revert the user but set it to be an integer user ID else the S2I build
# process will reject the builder image as can't tell if user name
# really maps to user ID for root.

USER 1000

# Set up Jupyter Notebook config
ENV CONFIG /home/jovyan/.jupyter/jupyter_notebook_config.py
ENV CONFIG_IPYTHON /home/jovyan/.ipython/profile_default/ipython_config.py

RUN bash -c 'source activate base && rm /home/jovyan/.jupyter/jupyter_notebook_config.py && jupyter notebook --generate-config --allow-root && \
    ipython profile create'

RUN echo "c.NotebookApp.ip = '*'" >>${CONFIG} && \
    echo "c.NotebookApp.open_browser = False" >>${CONFIG} && \
    echo "c.NotebookApp.iopub_data_rate_limit=10000000000" >>${CONFIG} && \
    echo "c.MultiKernelManager.default_kernel_name = 'python3'" >>${CONFIG}

RUN echo "c.InteractiveShellApp.exec_lines = ['%matplotlib inline']" >>${CONFIG_IPYTHON}

# ==== OUR STUFF FOLLOWS ====

# Enable a more liberal Content-Security-Policy so that we can display Jupyter
# in an iframe.
RUN echo "c.NotebookApp.tornado_settings = {" >> /etc/jupyter/jupyter_notebook_config.py && \
       echo "    'headers': {" >> /etc/jupyter/jupyter_notebook_config.py && \
       echo "        'Content-Security-Policy': \"frame-ancestors 'self' *\"" >> /etc/jupyter/jupyter_notebook_config.py && \
       echo "    }" >> /etc/jupyter/jupyter_notebook_config.py && \
       echo "}" >> /etc/jupyter/jupyter_notebook_config.py

# Override command to startup Jupyter notebook. The original is wrapped
# so we can set an environment variable for notebook password.

RUN pip install plotly pandas numpy
CMD [ "/opt/app-root/s2i/bin/run" ]
